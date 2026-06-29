class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :create, :read, :update, :destroy, to: :crud

    if user.admin?
      can :manage, :all
      cannot :destroy_without_predictions, User do |target_user|
        target_user.admin? || target_user.predictions.exists?
      end
    else
      can [:create, :read], Prediction
      can [:update, :destroy], Prediction do |prediction|
        (prediction.user_id == user.id) && prediction.open?
      end
      can :rnd_grp_pre, Cup
      can :read, :all
    end
  end
end
