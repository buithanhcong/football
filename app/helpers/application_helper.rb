module ApplicationHelper
  def matches_started
    return [] if APP_CONFIG["skip_validation"]
    Match.unscoped.where("time <= ?", Time.current).ids
  end

  def predicable_matches(user)
    @predicable_matches ||=
      if params[:action] == "edit"
        Match.where(id: Prediction.find(params[:prediction_id]).match_id)
      else
        taken_ids = Prediction.where(user: user).pluck(:match_id).compact
        Match.where(cup_id: params[:cup_id]).where.not(id: taken_ids + matches_started).includes(:team1, :team2)
      end
  end
end
