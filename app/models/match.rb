class Match < ActiveRecord::Base
  belongs_to :team1, class_name: "Team", foreign_key: "team1_id"
  belongs_to :team2, class_name: "Team", foreign_key: "team2_id"
  has_many :predictions
  belongs_to :cup

  default_scope { order(:time) }

  after_save :update_score, if: -> { closed? }

  def prediction_of(user)
    predictions.find_by(user: user)
  end

  def name(*_args)
    team1.name + ((prior1.nil? || prior1== 0) ? '' : "(-"+prior1.to_s+")") + ' vs ' + team2.name + ((prior2.nil? || prior2 == 0) ? '' : "(-"+prior2.to_s+")") + " (#{time.to_s(:match)})"
  end

  def short_name
    team1.name + ' vs ' + team2.name
  end

  def mainscores
    "#{mainscore1} - #{mainscore2}"
  end

  def subscores
    "#{subscore1} - #{subscore2}"
  end

  def fullscores
    if !subscore1.nil? && !subscore2.nil?
      if !penscore1.nil? && !penscore2.nil?
        subscores + " (#{penscore1} - #{penscore2})"
      else
        subscores
      end
    else
      mainscores
    end
  end

  def priorities
    if !knockout?
      "-"
    else 
      if !prior1.nil? && prior1 > 0
        "#{team1.name} -#{prior1} ~> #{rates}"
      else 
        if !prior2.nil? && prior2 > 0 
          "#{team2.name} -#{prior2} ~> #{rates}"
        else
          "- ~> #{rates}"
        end
      end
    end
  end

  def rates
    if knockout?
      "LPC: #{team1.name}(#{predictions.select{|p| p.winner_team == team1}.count}) - (#{predictions.select{|p| p.winner_team == team2}.count})#{team2.name}"
    else
      ""
    end
  end

  def winner
    if closed?
      if !subscore1.nil? && !subscore2.nil? && !penscore1.nil? && !penscore2.nil?
        subscore1 > subscore2 ? team1 :
        subscore1 < subscore2 ? team2 :
        penscore1 > penscore2 ? team1 :
        penscore1 < penscore2 ? team2 : nil
      else
        if !subscore1.nil? && !subscore2.nil?
          subscore1 > subscore2 ? team1 :
          subscore1 < subscore2 ? team2 : nil
        else
          mainscore1 > mainscore2 ? team1 :
          mainscore1 < mainscore2 ? team2 : nil
        end
      end
    end
  end

  def looser
    if closed?
      if !subscore1.nil? && !subscore2.nil? && !penscore1.nil? && !penscore2.nil?
        subscore1 > subscore2 ? team2 :
        subscore1 < subscore2 ? team1 :
        penscore1 > penscore2 ? team2 :
        penscore1 < penscore2 ? team1 : nil
      else
        if !subscore1.nil? && !subscore2.nil?
          subscore1 > subscore2 ? team2 :
          subscore1 < subscore2 ? team1 : nil
        else
          mainscore1 > mainscore2 ? team2 :
          mainscore1 < mainscore2 ? team1 : nil
        end
      end
    end
  end

  def prediction_winners
    if knockout?
      User.where(id: predictions.select{|p| p.win?}.map(&:user_id))
    else
      User.where(id: Prediction.where(match: self, mainscore1: mainscore1, mainscore2: mainscore2).map(&:user_id))
    end
  end

  def prediction_winners_count
    prediction_winners.count
  end

  def prediction_winners_names
    prediction_winners.map(&:name).join(", ")
  end

  def equal?
    closed? && (mainscore1 == mainscore2) 
  end

  def started?
    Time.now >= time
  end

  def closed?
    status == true
  end

  def human_status
    closed? ? 'Finished' : started? ? 'Started' : ''
  end

  def update_score
    update_teams_score
    update_predictions_reward
    update_users_score_reward
  end

  def update_teams_score
    if !knockout?
      team1.update_score
      team2.update_score
      if team1.played_matches.count == 3 && !cup.is_league?
        team1.update_status
      end
      if team2.played_matches.count == 3 && !cup.is_league?
        team2.update_status
      end
    else
      if !cup.is_league?
        winner.update(status: true)
        looser.update(status: false)
      end
    end
  end

  def update_predictions_reward
    if knockout?
      if prediction_winners_count == 0
        if cup.is_league?
          predictions.all.each do |prediction|
            prediction.update(reward: fee)
          end
        else
          cup.update(save_reward: fee*predictions.count)
          predictions.all.each do |prediction|
            prediction.update(reward: 0)
          end
        end
      else
        predictions.all.each do |prediction|
          if prediction.halfwin?
            prediction.update(reward: ((fee*predictions.count/2+cup.save_reward)/prediction_winners_count).round + fee/2)  
          elsif prediction.win?
            prediction.update(reward: ((fee*predictions.count+cup.save_reward)/prediction_winners_count).round)
          elsif prediction.halflose?
            prediction.update(reward: fee/2)
          else
            prediction.update(reward: 0)
          end
        end
        cup.update(save_reward: 0)
      end
    else
      predictions.all.each do |prediction|
        if prediction.win?
          prediction.update(reward: (cup.reward_percent*fee*valid_users_count/prediction_winners_count).round)
        else
          prediction.update(reward: 0)
        end
      end
    end
  end

  def update_users_score_reward
    Score.all.each do |score|
      score.update_score_reward
    end
  end

  def update_result
    require 'net/http'
    if updated_at.nil? || updated_at < 1.minutes.ago
      home_team_name = team1.name
      away_team_name = team2.name
      uri = URI.parse("https://api.football-data.org/v4/competitions/"+cup.result_id.to_s+"/matches?season="+Date.today.strftime("%Y")+"&dateFrom="+Date.yesterday.strftime("%Y-%m-%d")+"&dateTo="+Date.tomorrow.strftime("%Y-%m-%d"))
      #uri = URI.parse("http://api.football-data.org/v4/competitions/"+cup.result_id.to_s+"/matches")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      request = Net::HTTP::Get.new(uri.request_uri, {"X-Auth-Token"=>ENV['FOOTBALL_API_KEY']})
      resp = http.request(request)
      if resp.kind_of? Net::HTTPSuccess
        data = JSON.parse(resp.body)
        match_results = data['matches'].select{|m| (m['homeTeam']['name'] == home_team_name && m['awayTeam']['name'] == away_team_name)}
        if match_results.count > 0
          last_m = match_results.last
          ms1 = last_m['score']['fullTime']['home'].nil? ? nil : last_m['score']['fullTime']['home'] - (last_m['score'].key?('extraTime') ? (last_m['score']['extraTime']['home'].nil? ? 0 : last_m['score']['extraTime']['home']) : 0) - (last_m['score'].key?('penalties') ? (last_m['score']['penalties']['home'].nil? ? 0 : last_m['score']['penalties']['home']) : 0)
          ms2 = last_m['score']['fullTime']['away'].nil? ? nil : last_m['score']['fullTime']['away'] - (last_m['score'].key?('extraTime') ? (last_m['score']['extraTime']['away'].nil? ? 0 : last_m['score']['extraTime']['away']) : 0) - (last_m['score'].key?('penalties') ? (last_m['score']['penalties']['away'].nil? ? 0 : last_m['score']['penalties']['away']) : 0)
          ss1 = last_m['score'].key?('extraTime') ? last_m['score']['extraTime']['home'].nil? ? nil : (ms1 + last_m['score']['extraTime']['home']) : nil
          ss2 = last_m['score'].key?('extraTime') ? last_m['score']['extraTime']['away'].nil? ? nil : (ms2 + last_m['score']['extraTime']['away']) : nil
          ps1 = last_m['score'].key?('penalties') ? last_m['score']['penalties']['home'] : nil;
          ps2 = last_m['score'].key?('penalties') ? last_m['score']['penalties']['away'] : nil;
          if last_m['status'] == 'IN_PLAY' && !ms1.nil? && !ms2.nil?
            update(mainscore1: ms1, mainscore2: ms2, subscore1: ss1, subscore2: ss2, penscore1: ps1, penscore2: ps2, status: false)
          end
          if last_m['status'] == 'FINISHED' && !ms1.nil? && !ms2.nil?
            update(mainscore1: ms1, mainscore2: ms2, subscore1: ss1, subscore2: ss2, penscore1: ps1, penscore2: ps2, status: true)
          end
        end
      end
    end
  end

  def valid_users
    cup.active_users.select{|u| !u.predictions_of_cup(cup).order(match_id: :asc).first.match.knockout?}
  end

  def valid_users_count
    valid_users.count
  end

  def random_score
    randnum = rand(100)
    if randnum < 70
      rand(3)
    elsif randnum < 85
      3
    elsif randnum < 95
      4
    else
      5
    end
  end
end
