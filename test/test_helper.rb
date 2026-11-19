ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/mock'

module FactoryHelpers
  def create_cup(attrs = {})
    Cup.create!({ name: 'Cup', result_id: 0, reward_percent: 1.0, save_reward: 0,
                  start_date: Date.today, end_date: Date.today + 30 }.merge(attrs))
  end

  def create_team(cup, name, attrs = {})
    Team.create!({ cup: cup, name: name, score: 0, cup_group: 'A' }.merge(attrs))
  end

  def create_user(name, attrs = {})
    User.create!({ email: "#{name}@example.com", password: 'password123',
                   confirmed_at: Time.current }.merge(attrs))
  end

  def create_match(cup, team1, team2, attrs = {})
    Match.create!({ cup: cup, team1: team1, team2: team2, time: 1.day.from_now,
                    status: false, knockout: false, prior1: 0, prior2: 0, fee: 10,
                    special_final: false }.merge(attrs))
  end

  def create_prediction(match, user, score1, score2)
    Prediction.create!(match: match, user: user, cup: match.cup, mainscore1: score1, mainscore2: score2)
  end

  def finish_match(match, attrs)
    match.update!({ time: 1.hour.ago, status: true }.merge(attrs))
    match
  end
end

class ActiveSupport::TestCase
  include FactoryHelpers
end

class ActionDispatch::IntegrationTest
  include FactoryHelpers
  include Devise::Test::IntegrationHelpers
end
