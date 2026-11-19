class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  has_many :predictions
  has_many :matches, through: :predictions
  has_many :scores, dependent: :destroy

  def name
    email.gsub(/@.*/, '')
  end
  
  def get_score(cup)
    scores.find_by(cup: cup)&.score || 0
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

  def self.reset_pass(email)
    user = find_by(email: email)
    return puts("Email not found!") if user.nil?
    password = SecureRandom.alphanumeric(10)
    user.update!(password: password, password_confirmation: password)
    puts "Password reset to: #{password}"
  end
end
