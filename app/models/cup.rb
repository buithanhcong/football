class Cup < ActiveRecord::Base
  has_many :matches, dependent: :destroy
  has_many :teams, dependent: :destroy

  def total_matches_count
    matches.count
  end

  def played_matches
    matches.where(status: true)
  end

  def played_matches_count
    played_matches.count
  end

  def on_going
    start_date <= Date.today && end_date >= Date.today
  end

  def update_result
    pending = matches.includes(:team1, :team2).select { |m| m.started? && !m.closed? && m.refreshable? }
    return if pending.empty?
    data = FootballData.get("competitions/#{result_id}/matches", Match.result_window)
    pending.each { |m| m.apply_api_data(data) }
  end

  def update_group_stage_score
    matches.select{|match| (match.closed? && !match.knockout?)}.each do |m|
      m.recalculate_rewards
    end
  end

  def active_users
    User.where(id: Prediction.where(cup_id: id).select(:user_id))
  end

  def active_users_count
    active_users.count
  end

  def available_team_list
    @available_team_list ||= begin
      data = FootballData.get("competitions/#{result_id}/teams", season: Date.today.year)
      existing = teams.pluck(:name).to_set
      (data ? data['teams'] : []).map do |t|
        { id: t['id'], name: t['name'], coach: t.dig('coach', 'name') || 'No Coach Listed',
          status: existing.include?(t['name']) }
      end
    end
  end

  def available_match_list
    @available_match_list ||= begin
      data = FootballData.get("competitions/#{result_id}/matches", season: Date.today.year)
      existing = matches.includes(:team1, :team2).map(&:short_name).to_set
      (data ? data['matches'] : []).select { |m|
        m['status'] == 'TIMED' && m.dig('homeTeam', 'id') && m.dig('awayTeam', 'id')
      }.map do |m|
        name = "#{m.dig('homeTeam', 'name')} vs #{m.dig('awayTeam', 'name')}"
        { id: m['id'], name: name,
          date: Time.zone.parse(m['utcDate']).strftime('%d %b %Y, %H:%M'),
          status: existing.include?(name) }
      end
    end
  end
end
