class CupsController < ApplicationController
  load_and_authorize_resource cup_method: :cup_params
  before_action :set_cup, only: [:show, :edit, :update, :destroy, :rnd_grp_pre, :cal_grp_scr]
  before_action :set_free_cup_list, only: [:new, :create, :edit]

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
          m.prediction_of(current_user).update(mainscore1: m.random_score, mainscore2: m.random_score)
        end
      end
    end
    redirect_to @cup, notice: 'Randomize predtictions done.'
  end

  def cal_grp_scr
    @cup.update_group_stage_score
    redirect_to leader_board_url(stage: 'group')
  end

  def set_free_cup_list
    require 'net/http'
    uri = URI.parse("https://api.football-data.org/v4/competitions/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    request = Net::HTTP::Get.new(uri.request_uri, {"X-Auth-Token"=>ENV['FOOTBALL_API_KEY']})
    resp = http.request(request)
    if resp.kind_of? Net::HTTPSuccess
      data = JSON.parse(resp.body)
      @free_cup_list = data['competitions'].select{|c| (c['plan'] == 'TIER_ONE')}.map { |c| {id: c['id'], name: c['name'] } }
    else
      @free_cup_list = []
    end
  end

  private
    def set_cup
      @cup = Cup.find(params[:cup_id])
    end

    def cup_params
      params.require(:cup).permit(:name, :host, :logo, :start_date, :end_date, :is_league, :result_id, :reward_percent, :save_reward)
    end
end
