class Team < ActiveRecord::Base
  belongs_to :cup
  before_save :set_logourl, if: -> { new_record? || name_changed? || cup_id_changed? }

  def matches
    Match.where(cup: cup).where("team1_id = ? OR team2_id = ?", id, id)
  end

  def total_matches_count
    matches.count
  end

  def played_matches
    matches.where(status: true, knockout: false)
  end

  attr_writer :played_rows

  def played_rows
    @played_rows || played_matches.to_a
  end

  def won_matches
    played_rows.select { |m| m.winner_id == id }
  end

  def drew_matches
    played_rows.select { |m| m.mainscore1 == m.mainscore2 }
  end

  def loss_matches
    played_rows.select { |m| m.loser_id == id }
  end

  def goal_for
    played_rows.sum { |m| m.team1_id == id ? m.mainscore1 : m.mainscore2 }
  end

  def goal_against
    played_rows.sum { |m| m.team1_id == id ? m.mainscore2 : m.mainscore1 }
  end

  def remain_matches_count
    total_matches_count - played_rows.size
  end

  def update_score
    score = 0
    played_matches.each do |match|
      score += match.draw? ? 1 : (match.winner_id == id ? 3 : 0)
    end
    update(score: score)
  end

  def update_status
    group = Team.where(cup: cup, cup_group: cup_group).sort_by{ |t| [-t.score, t.goal_against-t.goal_for, -t.goal_for] }
    next_stage_teams = group.first(2)
    eliminated_teams = group.last(2)
    next_stage_teams.each do |t|
      t.update(status: true)
    end
    eliminated_teams.each do |t|
      t.update(status: false)
    end
  end

  private
    def set_logourl
      self.logourl = fetch_logourl || logourl.to_s
      true
    end

    def fetch_logourl
      return if cup.nil? || cup.result_id.to_i.zero?
      data = FootballData.get("competitions/#{cup.result_id}/teams", season: Date.today.year)
      return if data.nil?
      api_team = Array(data['teams']).reverse.find { |t| t['name'] == name }
      api_team ? api_team['crest'] : ''
    end
end
