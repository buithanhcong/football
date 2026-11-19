require 'net/http'

class FootballData
  BASE_URL = 'https://api.football-data.org/v4'.freeze
  TIMEOUT = 5

  def self.get(path, params = {})
    new.get(path, params)
  end

  def get(path, params = {})
    uri = URI.parse("#{BASE_URL}/#{path}")
    uri.query = URI.encode_www_form(params) if params.present?
    request = Net::HTTP::Get.new(uri.request_uri, 'X-Auth-Token' => ENV['FOOTBALL_API_KEY'])
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                               open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
  rescue StandardError => e
    Rails.logger.warn("FootballData request failed (#{path}): #{e.class}: #{e.message}")
    nil
  end
end
