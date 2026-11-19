class Prediction < ActiveRecord::Base
  belongs_to :match
  belongs_to :user
  belongs_to :cup

  validate :allow_update_reward_only

  validates :match_id, uniqueness: { scope: :user_id, message: "one prediction per match for each user" }

  after_save :update_score

  def update_score
    Score.find_or_create_by(user: user, cup: cup)
  end

  def allow_update_reward_only
    if id_changed? || match_id_changed? || user_id_changed? || cup_id_changed? || mainscore1_changed? || mainscore2_changed?
      validate_match
    end
  end

  def validate_match
    errors.add(:match, ' started !!!') if match.started? && !APP_CONFIG["skip_validation"]
    errors.add(:match, ' is in knockout stage!!! Must chose ONE winner!!!') if match.knockout? && (mainscore1 == mainscore2)
  end

  def locked?
    match.started? && !APP_CONFIG["skip_validation"]
  end

  def open?
    !locked?
  end

  def closed?
    match.closed?
  end

  def score
    match.knockout? ? (win? ? 2 : 0) : (win? ? 2 : (subwin? ? 1 : 0))
  end

  def mainscores
    "#{mainscore1} - #{mainscore2}"
  end

  def win?
    return false unless closed?
    return match.mainscore1 == mainscore1 && match.mainscore2 == mainscore2 unless match.knockout?
    predicted = mainscore1 <=> mainscore2
    return false if predicted.zero?
    handicap_results.any? { |outcome| outcome == predicted }
  end

  def subwin?
    closed? && (win? ? false :
      ( ((match.mainscore1 == match.mainscore2) && (mainscore1 == mainscore2)) ||
        ((match.mainscore1 >  match.mainscore2) && (mainscore1 >  mainscore2)) ||
        ((match.mainscore1 <  match.mainscore2) && (mainscore1 <  mainscore2)) ))
  end

  def halfwin?
    if match.knockout?
      closed? && win? && (((match.mainscore1 - match.prior1) - (match.mainscore2 - match.prior2)).abs == 0.25)
    else
      false
    end
  end

  def halflose?
    if match.knockout?
      closed? && !win? && (((match.mainscore1 - match.prior1) - (match.mainscore2 - match.prior2)).abs == 0.25)
    else
      false
    end
  end

  def winner_team
    (mainscore1 > mainscore2) ? match.team1 : ((mainscore1 < mainscore2) ? match.team2 : nil)
  end

  private

  def handicap_results
    pairs = [[match.mainscore1, match.mainscore2]]
    if match.special_final?
      pairs << [match.subscore1, match.subscore2]
      pairs << [match.penscore1, match.penscore2]
    end
    pairs.reject { |a, b| a.nil? || b.nil? }
         .map { |a, b| (a - match.prior1.to_f) <=> (b - match.prior2.to_f) }
  end
end
