class UsersController < ApplicationController
  before_action :authenticate_user!

  def index
    @cup = Cup.find(params[:cup_id])
    @stage = params[:stage]
    case @stage
    when 'group'
      @userscores = stage_scores(false).includes(:user).order('score desc nulls last, reward desc').to_a
      @groupmatches = closed_matches(false)
      @predictions = predictions_by_cell(@groupmatches, @userscores)
    when 'knockout'
      @userknockoutrewards = stage_scores(true).includes(:user).sort_by { |s| -s.knockout_profit }
      @knockoutmatches = closed_matches(true)
      @predictions = predictions_by_cell(@knockoutmatches, @userknockoutrewards)
    end
  end

  def edit
    @user = current_user
  end

  def update_password
    @user = current_user
    if @user.update_with_password(user_params)
      # Sign in the user by passing validation in case their password changed
      # bypass_sign_in(@user)
      redirect_to root_path
    else
      render "edit"
    end
  end

  def list
    @users = User.order(created_at: :desc)
    @cup = Cup.find(params[:cup_id])
    @active_users = @cup.active_users.to_a
    @prediction_counts = Prediction.where(cup_id: @cup.id).group(:user_id).count
    @user_scores = Score.where(cup_id: @cup.id).pluck(:user_id, :score).to_h
  end

  def reset_pass
    authorize! :reset_pass, User
    user = User.find(params[:u_id])
    password = SecureRandom.alphanumeric(10)
    if user.update(password: password, password_confirmation: password)
      redirect_to users_list_url(cup_id: params[:cup_id]),
        notice: "Password of #{user.name} reset to: #{password}"
    else
      redirect_to users_list_url(cup_id: params[:cup_id]), alert: 'Password reset failed!'
    end
  end

  def remove_cup
    authorize! :remove_cup, User
    cup = Cup.find(params[:cup_id])
    User.find(params[:u_id]).predictions_of_stage(cup, false).each(&:destroy)
    redirect_to users_list_url(cup_id: cup.id), notice: 'User removed from the Cup!'
  end

  def destroy_without_predictions
    @user = User.find(params[:id])

    authorize! :destroy_without_predictions, @user

    if @user.destroy
      flash[:notice] = "User successfully deleted."
    else
      flash[:alert] = "Failed to delete user."
    end

    # Redirect back to the cup-specific user list, or fall back to standard index
    if params[:cup_id].present?
      redirect_to users_list_path(cup_id: params[:cup_id])
    else
      redirect_to users_index_path
    end
  rescue CanCan::AccessDenied
    redirect_to users_index_path, alert: "You cannot delete this user."
  end

  private

  def closed_matches(knockout)
    @cup.matches.where(knockout: knockout, status: true).includes(:team1, :team2).to_a.reverse
  end

  def predictions_by_cell(matches, scores)
    Prediction.where(match_id: matches.map(&:id), user_id: scores.map(&:user_id))
              .includes(match: [:team1, :team2])
              .index_by { |p| [p.match_id, p.user_id] }
  end

  def stage_scores(knockout)
    active_ids = Prediction.joins(:match).unscope(:order)
                           .where(cup_id: @cup.id, matches: { knockout: knockout, status: true })
                           .distinct.pluck(:user_id)
    admin_ids = User.where(admin: true).select(:id)
    Score.where(cup_id: @cup.id, user_id: active_ids).where.not(user_id: admin_ids)
  end

  def user_params
    params.require(:user).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end
