class MatchesController < ApplicationController
  load_and_authorize_resource param_method: :match_params
  before_action :set_match, only: [:show, :edit, :update, :destroy, :cal_scr]
  before_action :set_cup, only: [:index, :create, :new]

  def index
    if @cup.result_id != 0
      @cup.update_result
    end
    @matches = @cup.matches.order(:time)
  end

  def show
    @cup = @match.cup
  end

  def new
    @match = Match.new(cup_id: @cup.id)
  end

  def edit
  end

  def create
    @match = Match.new(match_params.merge(cup_id: @cup.id))

    if @match.save
      redirect_to @match, notice: 'Match was successfully created.'
    else
      render :new
    end
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: 'Match was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_path(cup_id: @match.cup_id), 
      notice: 'Match was successfully destroyed.'
  end

  def cal_scr
    @match.update_predictions_reward
    @match.update_users_score_reward
    redirect_to matches_path(cup_id: @match.cup_id), notice: 'Match was successfully updated.'
  end

  private
    def set_match
      @match = Match.find(params[:match_id])
    end

    def set_cup
      @cup = Cup.find(params[:cup_id])
    end

    def match_params
      params.require(:match).permit(
        :team1_id,
        :team2_id,
        :time,
        :status,
        :mainscore1,
        :mainscore2,
        :subscore1,
        :subscore2,
        :penscore1,
        :penscore2,
        :knockout,
        :prior1,
        :prior2,
        :fee,
        :special_final
      )
    end
end
