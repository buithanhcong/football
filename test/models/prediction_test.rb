require 'test_helper'

class PredictionTest < ActiveSupport::TestCase
  setup do
    @cup = create_cup
    @a = create_team(@cup, 'Alpha')
    @b = create_team(@cup, 'Beta')
    @user = create_user('alice')
  end

  def prediction_for(match_attrs, score1, score2)
    match = Match.new({ cup: @cup, team1: @a, team2: @b, status: true, knockout: false,
                        prior1: 0, prior2: 0, special_final: false }.merge(match_attrs))
    Prediction.new(match: match, user: @user, cup: @cup, mainscore1: score1, mainscore2: score2)
  end

  test 'exact score is worth two points' do
    prediction = prediction_for({ mainscore1: 2, mainscore2: 1 }, 2, 1)
    assert prediction.win?
    assert_not prediction.subwin?
    assert_equal 2, prediction.score
  end

  test 'correct outcome is worth one point' do
    prediction = prediction_for({ mainscore1: 2, mainscore2: 1 }, 3, 0)
    assert_not prediction.win?
    assert prediction.subwin?
    assert_equal 1, prediction.score
  end

  test 'correct draw with another score is worth one point' do
    assert_equal 1, prediction_for({ mainscore1: 0, mainscore2: 0 }, 2, 2).score
  end

  test 'wrong outcome is worth nothing' do
    assert_equal 0, prediction_for({ mainscore1: 2, mainscore2: 1 }, 0, 1).score
  end

  test 'open match is never a win' do
    prediction = prediction_for({ status: false, mainscore1: nil, mainscore2: nil }, 1, 0)
    assert_not prediction.win?
    assert_not prediction.subwin?
  end

  test 'knockout win depends on the handicap' do
    match = { knockout: true, mainscore1: 1, mainscore2: 0, prior1: 1.5, prior2: 0 }
    assert prediction_for(match, 0, 1).win?
    assert_not prediction_for(match, 1, 0).win?
  end

  test 'knockout level handicap is not a win' do
    match = { knockout: true, mainscore1: 1, mainscore2: 0, prior1: 1, prior2: 0 }
    assert_not prediction_for(match, 1, 0).win?
    assert_not prediction_for(match, 0, 1).win?
  end

  test 'knockout quarter handicap is a half win or half lose' do
    match = { knockout: true, mainscore1: 1, mainscore2: 0, prior1: 0.75, prior2: 0 }
    winner = prediction_for(match, 1, 0)
    loser = prediction_for(match, 0, 1)
    assert winner.win?
    assert winner.halfwin?
    assert_not loser.win?
    assert loser.halflose?
  end

  test 'nil priors count as zero' do
    match = { knockout: true, mainscore1: 1, mainscore2: 0, prior1: nil, prior2: nil }
    assert prediction_for(match, 1, 0).win?
  end

  test 'special final also counts extra time and penalties' do
    match = { knockout: true, special_final: true, mainscore1: 1, mainscore2: 1,
              subscore1: 1, subscore2: 1, penscore1: 5, penscore2: 4 }
    assert prediction_for(match, 1, 0).win?
    assert_not prediction_for(match, 0, 1).win?
  end

  test 'regular knockout ignores penalties' do
    match = { knockout: true, special_final: false, mainscore1: 1, mainscore2: 1,
              subscore1: 1, subscore2: 1, penscore1: 5, penscore2: 4 }
    assert_not prediction_for(match, 1, 0).win?
  end

  test 'winner_team follows the predicted score' do
    assert_equal @a, prediction_for({}, 1, 0).winner_team
    assert_equal @b, prediction_for({}, 0, 1).winner_team
    assert_nil prediction_for({}, 1, 1).winner_team
  end

  test 'cannot predict a match that has started' do
    match = create_match(@cup, @a, @b, time: 1.hour.ago)
    prediction = Prediction.new(match: match, user: @user, cup: @cup, mainscore1: 1, mainscore2: 0)
    assert_not prediction.valid?
    assert prediction.errors[:match].any?
  end

  test 'knockout prediction must choose a winner' do
    match = create_match(@cup, @a, @b, knockout: true)
    prediction = Prediction.new(match: match, user: @user, cup: @cup, mainscore1: 1, mainscore2: 1)
    assert_not prediction.valid?
  end

  test 'one prediction per user and match' do
    match = create_match(@cup, @a, @b)
    create_prediction(match, @user, 1, 0)
    duplicate = Prediction.new(match: match, user: @user, cup: @cup, mainscore1: 2, mainscore2: 0)
    assert_not duplicate.valid?
  end

  test 'saving a prediction creates the score row' do
    match = create_match(@cup, @a, @b)
    assert_difference -> { Score.where(user: @user, cup: @cup).count }, 1 do
      create_prediction(match, @user, 1, 0)
    end
  end

  test 'open and locked follow the kickoff time' do
    open_match = create_match(@cup, @a, @b)
    prediction = create_prediction(open_match, @user, 1, 0)
    assert prediction.open?
    open_match.update_columns(time: 1.minute.ago)
    assert prediction.reload.locked?
  end
end
