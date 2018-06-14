class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :predictions
  has_many :matches, through: :predictions

  def name
    email.gsub(/@.*/, '')
  end
  
  def get_score(cup)
    score_user_at_cup = Score.where(user: self, cup: cup)
    score_user_at_cup.count == 0 ? 0 : score_user_at_cup.first.score 
  end

  def inactive?(cup)
    (predictions.where('user_id = ? AND cup_id = ?', id, cup).count == 0)
  end
end
