class Match < ActiveRecord::Base
  belongs_to :team1, class_name: "Team", foreign_key: "team1_id"
  belongs_to :team2, class_name: "Team", foreign_key: "team2_id"
  has_many :predictions, inverse_of: :match
  belongs_to :cup

  default_scope { order(:time) }

  after_save :update_score, if: -> { closed? }

  def prediction_of(user)
    predictions.find_by(user: user)
  end

  def name(*_args)
    team1.name + ((prior1.nil? || prior1== 0) ? '' : "(-"+prior1.to_s+")") + ' vs ' + team2.name + ((prior2.nil? || prior2 == 0) ? '' : "(-"+prior2.to_s+")") + " (#{time.to_fs(:match)})"
  end

  def short_name
    team1.name + ' vs ' + team2.name
  end

  def mainscores
    "#{mainscore1} - #{mainscore2}"
  end

  def subscores
    "#{subscore1} - #{subscore2}"
  end

  def fullscores
    if !subscore1.nil? && !subscore2.nil?
      if !penscore1.nil? && !penscore2.nil?
        subscores + " (#{penscore1} - #{penscore2})"
      else
        subscores
      end
    else
      mainscores
    end
  end

  def priorities
    if !knockout?
      "-"
    else 
      if !prior1.nil? && prior1 > 0
        "#{team1.name} -#{prior1} ~> #{rates}"
      else 
        if !prior2.nil? && prior2 > 0 
          "#{team2.name} -#{prior2} ~> #{rates}"
        else
          "- ~> #{rates}"
        end
      end
    end
  end

  def rates
    if knockout?
      "LPC: #{team1.name}(#{predictions.select{|p| p.winner_team == team1}.count}) - (#{predictions.select{|p| p.winner_team == team2}.count})#{team2.name}"
    else
      ""
    end
  end

  def winner
    team_by_id(winner_id)
  end

  def loser
    team_by_id(loser_id)
  end

  def winner_id
    closed? ? decisive_ids&.first : nil
  end

  def loser_id
    closed? ? decisive_ids&.last : nil
  end

  def prediction_winners
    if knockout?
      User.where(id: predictions.select{|p| p.win?}.map(&:user_id))
    else
      User.where(id: Prediction.where(match: self, mainscore1: mainscore1, mainscore2: mainscore2).map(&:user_id))
    end
  end

  def prediction_winners_count
    prediction_winners.count
  end

  def prediction_winners_names
    predictions.select(&:win?).map { |p| p.user.name }.join(", ")
  end

  def draw?
    closed? && (mainscore1 == mainscore2) 
  end

  def started?
    Time.now >= time
  end

  def closed?
    status == true
  end

  def human_status
    closed? ? 'Finished' : started? ? 'Started' : ''
  end

  def update_score
    update_teams_score
    update_predictions_reward
    update_users_score_reward
  end

  def update_teams_score
    if knockout?
      unless cup.is_league?
        winner&.update(status: true)
        loser&.update(status: false)
      end
    else
      [team1, team2].each do |team|
        team.update_score
        team.update_status if team.played_matches.count == 3 && !cup.is_league?
      end
    end
  end

  def update_predictions_reward
    knockout? ? reward_knockout_predictions : reward_group_predictions
  end

  def update_users_score_reward
    Score.where(cup_id: cup_id).find_each do |score|
      score.update_score_reward
    end
  end

  def self.result_window
    { season: Date.today.year,
      dateFrom: Date.yesterday.strftime('%Y-%m-%d'),
      dateTo: Date.tomorrow.strftime('%Y-%m-%d') }
  end

  def refreshable?
    updated_at.nil? || updated_at < 1.minute.ago
  end

  def update_result
    return unless refreshable?
    apply_api_data(FootballData.get("competitions/#{cup.result_id}/matches", self.class.result_window))
  end

  def apply_api_data(data)
    return if data.nil? || data['matches'].nil?
    api_match = data['matches'].reverse.find do |m|
      m.dig('homeTeam', 'name') == team1.name && m.dig('awayTeam', 'name') == team2.name
    end
    return if api_match.nil?
    result = MatchResult.new(api_match)
    if result.finished?
      update(result.attributes.merge(status: true))
    elsif result.in_play?
      update(result.attributes.merge(status: false))
    end
  end

  def recalculate_rewards
    transaction do
      update_predictions_reward
      update_users_score_reward
    end
  end

  def valid_users
    first_match_by_user = Prediction.where(cup_id: cup_id).group(:user_id).minimum(:match_id)
    knockout_ids = Match.unscoped.where(id: first_match_by_user.values.uniq, knockout: true).pluck(:id)
    User.where(id: first_match_by_user.reject { |_, match_id| knockout_ids.include?(match_id) }.keys)
  end

  def valid_users_count
    valid_users.count
  end

  def random_score
    randnum = rand(100)
    if randnum < 70
      rand(3)
    elsif randnum < 85
      3
    elsif randnum < 95
      4
    else
      5
    end
  end

  private

  def reward_knockout_predictions
    list = predictions.to_a
    fee = self.fee.to_i
    pot = fee * list.size
    winners = list.count(&:win?)
    if winners.zero?
      if cup.is_league?
        list.each { |p| p.update(reward: fee) }
      else
        cup.update(save_reward: pot)
        list.each { |p| p.update(reward: 0) }
      end
      return
    end
    saved = cup.save_reward.to_i
    list.each do |p|
      reward =
        if p.halfwin?
          ((pot / 2 + saved) / winners).round + fee / 2
        elsif p.win?
          ((pot + saved) / winners).round
        elsif p.halflose?
          fee / 2
        else
          0
        end
      p.update(reward: reward)
    end
    cup.update(save_reward: 0)
  end

  def reward_group_predictions
    winning, losing = predictions.to_a.partition(&:win?)
    unless winning.empty?
      share = (cup.reward_percent.to_f * fee.to_i * valid_users_count / prediction_winners_count).round
      winning.each { |p| p.update(reward: share) }
    end
    losing.each { |p| p.update(reward: 0) }
  end

  def team_by_id(team_id)
    return if team_id.nil?
    team_id == team1_id ? team1 : team2
  end

  def decisive_ids
    order =
      if [subscore1, subscore2].none?(&:nil?)
        by_sub = subscore1 <=> subscore2
        by_sub.zero? && [penscore1, penscore2].none?(&:nil?) ? penscore1 <=> penscore2 : by_sub
      else
        mainscore1 <=> mainscore2
      end
    case order
    when 1 then [team1_id, team2_id]
    when -1 then [team2_id, team1_id]
    end
  end
end
