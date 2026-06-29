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
      m.update_predictions_reward
      m.update_users_score_reward
    end
  end

  def active_users
    User.select{|u| !u.inactive?(self)}
  end

  def active_users_count
    active_users.count
  end

  def available_team_list
    require 'net/http'
    uri = URI.parse("https://api.football-data.org/v4/competitions/"+result_id.to_s+"/teams?season="+Date.today.strftime("%Y"))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    request = Net::HTTP::Get.new(uri.request_uri, {"X-Auth-Token"=>ENV['FOOTBALL_API_KEY']})
    resp = http.request(request)
    if resp.kind_of? Net::HTTPSuccess
      existing_team_names = teams.pluck(:name)
      data = JSON.parse(resp.body)
      @available_team_list = data['teams'].map { |t| { id: t['id'], name: t['name'], coach: t.dig('coach', 'name') || 'No Coach Listed', status: existing_team_names.include?(t['name']) } }
    else
      @available_team_list = []
    end
  end

  def available_match_list
    require 'net/http'
    uri = URI.parse("https://api.football-data.org/v4/competitions/"+result_id.to_s+"/matches?season="+Date.today.strftime("%Y"))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    request = Net::HTTP::Get.new(uri.request_uri, {"X-Auth-Token"=>ENV['FOOTBALL_API_KEY']})
    resp = http.request(request)
    if resp.kind_of?(Net::HTTPSuccess)
      existing_match_names = matches.map(&:short_name).to_set
      data = JSON.parse(resp.body)
      @available_match_list = data['matches'].select { |m|
        m['status'] == 'TIMED' && m.dig('homeTeam', 'id') && m.dig('awayTeam', 'id')
      }.map { |e| 
        match_name = "#{e.dig('homeTeam', 'name')} vs #{e.dig('awayTeam', 'name')}"
        localized_time = Time.zone.parse(e['utcDate'])
        { 
          id: e['id'], 
          name: match_name,
          date: localized_time.strftime("%d %b %Y, %H:%M"),
          status: existing_match_names.include?(match_name)
        } 
      }
    else
      @available_match_list = []
    end
  end
end
