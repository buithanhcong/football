require 'test_helper'

class MatchTest < ActiveSupport::TestCase
  setup do
    @cup = create_cup
    @a = create_team(@cup, 'Alpha')
    @b = create_team(@cup, 'Beta')
  end

  def unsaved(attrs)
    Match.new({ cup: @cup, team1: @a, team2: @b, status: true }.merge(attrs))
  end

  test 'winner and loser follow the main score' do
    match = unsaved(mainscore1: 2, mainscore2: 1)
    assert_equal @a, match.winner
    assert_equal @b, match.loser
    assert_equal @b.id, match.loser_id
  end

  test 'away win' do
    match = unsaved(mainscore1: 0, mainscore2: 1)
    assert_equal @b, match.winner
    assert_equal @a, match.loser
  end

  test 'draw has no winner or loser' do
    match = unsaved(mainscore1: 1, mainscore2: 1)
    assert_nil match.winner
    assert_nil match.loser
    assert match.draw?
  end

  test 'open match has no winner' do
    match = unsaved(status: false, mainscore1: 2, mainscore2: 0)
    assert_nil match.winner
    assert_not match.draw?
  end

  test 'extra time decides before the main score' do
    match = unsaved(mainscore1: 1, mainscore2: 1, subscore1: 1, subscore2: 2)
    assert_equal @b, match.winner
  end

  test 'penalties decide when extra time is level' do
    match = unsaved(mainscore1: 1, mainscore2: 1, subscore1: 1, subscore2: 1, penscore1: 4, penscore2: 5)
    assert_equal @b, match.winner
    assert_equal @a, match.loser
  end

  test 'level after extra time without penalties has no winner' do
    match = unsaved(mainscore1: 1, mainscore2: 1, subscore1: 1, subscore2: 1)
    assert_nil match.winner
  end

  test 'group stage rewards go to exact predictions only' do
    alice = create_user('alice')
    bob = create_user('bob')
    match = create_match(@cup, @a, @b)
    exact = create_prediction(match, alice, 2, 1)
    wrong = create_prediction(match, bob, 0, 0)
    finish_match(match, mainscore1: 2, mainscore2: 1)
    assert_equal 20, exact.reload.reward
    assert_equal 0, wrong.reload.reward
    assert_equal [2, 20], [Score.find_by(user: alice, cup: @cup).score, Score.find_by(user: alice, cup: @cup).reward]
    assert_equal 0, Score.find_by(user: bob, cup: @cup).score
  end

  test 'same winner earns one point' do
    alice = create_user('alice')
    match = create_match(@cup, @a, @b)
    create_prediction(match, alice, 3, 0)
    finish_match(match, mainscore1: 1, mainscore2: 0)
    assert_equal 1, Score.find_by(user: alice, cup: @cup).score
  end

  test 'knockout pot is shared between the winners' do
    alice = create_user('alice')
    bob = create_user('bob')
    match = create_match(@cup, @a, @b, knockout: true)
    right = create_prediction(match, alice, 1, 0)
    wrong = create_prediction(match, bob, 0, 1)
    finish_match(match, mainscore1: 2, mainscore2: 1)
    assert_equal 20, right.reload.reward
    assert_equal 0, wrong.reload.reward
  end

  test 'knockout without winners saves the pot for the next match' do
    alice = create_user('alice')
    match = create_match(@cup, @a, @b, knockout: true)
    prediction = create_prediction(match, alice, 0, 1)
    finish_match(match, mainscore1: 2, mainscore2: 1)
    assert_equal 0, prediction.reload.reward
    assert_equal 10, @cup.reload.save_reward
  end

  test 'knockout without winners refunds the fee in a league' do
    league = create_cup(is_league: true)
    x = create_team(league, 'X')
    y = create_team(league, 'Y')
    alice = create_user('alice')
    match = create_match(league, x, y, knockout: true)
    prediction = create_prediction(match, alice, 0, 1)
    finish_match(match, mainscore1: 2, mainscore2: 1)
    assert_equal 10, prediction.reload.reward
  end

  test 'saved reward is paid out and reset' do
    @cup.update!(save_reward: 30)
    alice = create_user('alice')
    match = create_match(@cup, @a, @b, knockout: true)
    prediction = create_prediction(match, alice, 1, 0)
    finish_match(match, mainscore1: 1, mainscore2: 0)
    assert_equal 40, prediction.reload.reward
    assert_equal 0, @cup.reload.save_reward
  end

  test 'valid_users skips users whose first prediction is a knockout' do
    alice = create_user('alice')
    bob = create_user('bob')
    group = create_match(@cup, @a, @b)
    knockout = create_match(@cup, @a, @b, knockout: true)
    create_prediction(group, alice, 1, 0)
    create_prediction(knockout, bob, 1, 0)
    assert_equal [alice.id], group.valid_users.pluck(:id)
    assert_equal 1, group.valid_users_count
  end

  test 'apply_api_data closes a finished match' do
    match = create_match(@cup, @a, @b, time: 1.hour.ago)
    data = { 'matches' => [{ 'status' => 'FINISHED',
                             'homeTeam' => { 'name' => 'Alpha' }, 'awayTeam' => { 'name' => 'Beta' },
                             'score' => { 'fullTime' => { 'home' => 2, 'away' => 0 } } }] }
    match.apply_api_data(data)
    match.reload
    assert match.closed?
    assert_equal [2, 0], [match.mainscore1, match.mainscore2]
  end

  test 'apply_api_data marks a live match as not closed' do
    match = create_match(@cup, @a, @b, time: 1.hour.ago)
    data = { 'matches' => [{ 'status' => 'IN_PLAY',
                             'homeTeam' => { 'name' => 'Alpha' }, 'awayTeam' => { 'name' => 'Beta' },
                             'score' => { 'fullTime' => { 'home' => 1, 'away' => 1 } } }] }
    match.apply_api_data(data)
    assert_not match.reload.closed?
    assert_equal 1, match.mainscore1
  end

  test 'apply_api_data ignores missing data and other fixtures' do
    match = create_match(@cup, @a, @b)
    assert_nil match.apply_api_data(nil)
    assert_nil match.apply_api_data({})
    assert_nil match.apply_api_data({ 'matches' => [{ 'homeTeam' => { 'name' => 'Other' }, 'awayTeam' => { 'name' => 'Beta' } }] })
    assert_not match.reload.closed?
  end

  test 'name uses the match time format' do
    match = create_match(@cup, @a, @b, time: Time.utc(2026, 6, 12, 18, 30))
    assert_includes match.name, 'Alpha vs Beta'
    assert_includes match.name, match.time.to_fs(:match)
  end
end
