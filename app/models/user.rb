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

  def predictions_of_cup(cup)
    predictions.where(cup: cup)
  end

  def inactive?(cup)
    predictions_of_cup(cup).count == 0
  end
  
  def predictions_of_stage(cup, knockout)
    predictions_of_cup(cup).select{|p| (p.match.knockout == knockout) && p.match.closed?}
    #predictions_of_cup(cup).select{|p| (p.match.knockout == knockout)}
  end

  def self.reset_pass(i_email)
    # Its static method
    @u = find_by(email: i_email)
    if @u.nil?
      puts "Email not found!"
    else
      require 'bcrypt'
      @u.update(encrypted_password: BCrypt::Password.create("12345678"))
      puts "Password reset done!"
    end
  end
end
