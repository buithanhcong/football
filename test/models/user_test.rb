require 'test_helper'

class UserTest < ActiveSupport::TestCase
  setup do
    @cup = create_cup
    @a = create_team(@cup, 'Alpha')
    @b = create_team(@cup, 'Beta')
    @user = create_user('alice')
  end

  test 'name is the part of the email before the at sign' do
    assert_equal 'alice', @user.name
  end

  test 'inactive until the user predicts in the cup' do
    assert @user.inactive?(@cup)
    create_prediction(create_match(@cup, @a, @b), @user, 1, 0)
    assert_not @user.inactive?(@cup)
  end

  test 'get_score defaults to zero and reads the cup score' do
    assert_equal 0, @user.get_score(@cup)
    match = create_match(@cup, @a, @b)
    create_prediction(match, @user, 1, 0)
    finish_match(match, mainscore1: 1, mainscore2: 0)
    assert_equal 2, @user.get_score(@cup)
  end

  test 'predictions_of_stage only returns closed matches of that stage' do
    group = create_match(@cup, @a, @b)
    knockout = create_match(@cup, @a, @b, knockout: true)
    open_group = create_match(@cup, @a, @b)
    [group, knockout, open_group].each { |m| create_prediction(m, @user, 1, 0) }
    finish_match(group, mainscore1: 1, mainscore2: 0)
    finish_match(knockout, mainscore1: 1, mainscore2: 0)
    assert_equal [group.id], @user.predictions_of_stage(@cup, false).map(&:match_id)
    assert_equal [knockout.id], @user.predictions_of_stage(@cup, true).map(&:match_id)
  end

  test 'score computes totals and knockout profit' do
    group = create_match(@cup, @a, @b)
    knockout = create_match(@cup, @a, @b, knockout: true)
    create_prediction(group, @user, 1, 0)
    create_prediction(knockout, @user, 1, 0)
    finish_match(group, mainscore1: 1, mainscore2: 0)
    finish_match(knockout, mainscore1: 1, mainscore2: 0)
    score = Score.find_by(user: @user, cup: @cup)
    assert_equal 2, score.score
    assert_equal 10, score.reward
    assert_equal 10, score.knockout_reward
    assert_equal 10, score.knockout_fee
    assert_equal 0, score.knockout_profit
  end
end
