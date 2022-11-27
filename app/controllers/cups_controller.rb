class CupsController < ApplicationController
  load_and_authorize_resource cup_method: :cup_params
  before_action :set_cup, only: [:show, :edit, :update, :destroy, :rnd_grp_pre, :cal_grp_scr]

  def index
    @cups = Cup.all
  end

  def show
    if @cup.result_id != 0
      @cup.update_result
    end
    @nextmatches = @cup.matches.where("time >= ?", Time.now).order(time: :asc).first(5)
    @prematches = @cup.matches.where("time <= ?", Time.now).reorder(time: :desc).first(5)
  end

  def new
    @cup = Cup.new
  end

  def edit
  end

  def create
    @cup = Cup.new(cup_params)

    if @cup.save
      redirect_to @cup, notice: 'Cup was successfully created.'
    else
      render :new
    end
  end

  def update
    if @cup.update(cup_params)
      redirect_to @cup, notice: 'Cup was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @cup.destroy
    redirect_to cups_url, notice: 'Cup was successfully destroyed.'
  end

  def rnd_grp_pre
    @cup.matches.each do |m|
      if (!m.started? && !m.knockout?)
        if m.prediction_of(current_user).nil?
          @prediction = Prediction.new(user_id: current_user.id, cup_id: @cup.id, match_id: m.id, mainscore1: m.random_score, mainscore2: m.random_score)
          @prediction.save
        else
          m.prediction_of(current_user).update_attributes(mainscore1: m.random_score, mainscore2: m.random_score)
        end
      end
    end
    redirect_to @cup, notice: 'Randomize predtictions done.'
  end

  def cal_grp_scr
    @cup.update_group_stage_score
    redirect_to leader_board_url(stage: 'group')
  end

  private
    def set_cup
      @cup = Cup.find(params[:cup_id])
    end

    def cup_params
      params.require(:cup).permit(:name, :host, :logo, :start_date, :end_date, :is_league, :result_id, :reward_percent, :save_reward)
    end
end
