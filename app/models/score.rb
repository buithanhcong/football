class Score < ActiveRecord::Base
  belongs_to :user
  belongs_to :cup

  def update_score_reward
    group, knockout = user.predictions_of_cup(cup).includes(:match).partition { |p| !p.match.knockout? }
    update(
      score: group.sum { |p| p.win? ? 2 : (p.subwin? ? 1 : 0) },
      reward: group.sum { |p| p.reward.to_i },
      knockout_reward: knockout.sum { |p| p.reward.to_i },
      knockout_fee: knockout.select { |p| p.match.closed? }.sum { |p| p.match.fee.to_i }
    )
  end

  def knockout_profit
    knockout_reward.to_i - knockout_fee.to_i
  end
end
