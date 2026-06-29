class UsersController < ApplicationController
  before_action :authenticate_user!

  def index
    @cup = Cup.find(params[:cup_id])
    @stage = params[:stage]
    admin_ids = Score.where(user_id: User.where(admin: true).ids).ids
    if @stage == 'group'
      inactive_ids = Score.where(user_id: User.select{|u| u.predictions_of_stage(@cup, false).count == 0}.map{|u| u.id}).ids
      ids = Score.where(cup_id: @cup.id).ids - admin_ids - inactive_ids
      @userscores = Score.where(id: ids).order('score desc nulls last, reward desc')
      @groupmatches = @cup.matches.where(knockout: false)
    end
    if @stage == 'knockout'
      inactive_ids = Score.where(user_id: User.select{|u| u.predictions_of_stage(@cup, true).count == 0}.map{|u| u.id}).ids
      ids = Score.where(cup_id: @cup.id).ids - admin_ids - inactive_ids
      @userknockoutrewards = Score.where(id: ids).sort_by{ |u| [-u.knockout_profit] }
      @knockoutmatches = @cup.matches.where(knockout: true)
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
  end

  def reset_pass
    @cup = Cup.find(params[:cup_id])
    @u = User.find(params[:u_id])
    if @u.nil?
      if @cup.nil?
        redirect_to users_list_url, notice: 'User not found!'
      else
        redirect_to users_list_url(cup_id: @cup.id), notice: 'User not found!'
      end
    else
      require 'bcrypt'
      @u.update(encrypted_password: BCrypt::Password.create("12345678"))
      if @cup.nil?
        redirect_to users_list_url, notice: 'Password reset done!'
      else
        redirect_to users_list_url(cup_id: @cup.id), notice: 'Password reset done!'
      end
    end
  end

  def remove_cup
    @cup = Cup.find(params[:cup_id])
    @u = User.find(params[:u_id])
    if @u.nil?
      redirect_to users_list_url(cup_id: @cup.id), notice: 'User not found!'
    else
      @u.predictions_of_stage(@cup, false).each do |p|
        p.destroy
      end
      redirect_to users_list_url(cup_id: @cup.id), notice: 'User removed from the Cup!'
    end
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

  def user_params
    params.require(:user).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end
