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
    matches.select{|match| (match.started? && !match.closed?)}.each do |m|
      m.update_result
    end
  end

  def update_group_stage_score
    matches.select{|match| (match.closed? && !match.knockout?)}.each do |m|
      m.update_score
    end
  end

  def active_users
    User.select{|u| !u.inactive?(self)}
  end

  def active_users_count
    active_users.count
  end
end
