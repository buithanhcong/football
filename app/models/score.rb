class Score < ActiveRecord::Base
  belongs_to :user
  belongs_to :cup

  def update_score_reward
    score = 0
    user.predictions_of_cup(cup).each do |prediction|
      next if prediction.match.knockout?
      score += prediction.win? ? 2 : (prediction.subwin? ? 1 : 0)
    end
    update(score: score)
    reward = 0
    knockout_reward = 0
    user.predictions_of_cup(cup).each do |prediction|
      if prediction.match.knockout?
        knockout_reward += prediction.reward.nil? ? 0 : prediction.reward
      else
        reward += prediction.reward.nil? ? 0 : prediction.reward
      end
    end
    update(reward: reward)
    update(knockout_reward: knockout_reward)
    knockout_fee = 0
    user.predictions_of_stage(cup, true).each do |p|
      knockout_fee += p.match.fee
    end
    update(knockout_fee: knockout_fee)
  end

  def knockout_profit
    knockout_reward - knockout_fee
  end
end
