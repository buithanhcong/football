require 'test_helper'

class CupTest < ActiveSupport::TestCase
  setup do
    @cup = create_cup(result_id: 2000)
    FootballData.stub :get, nil do
      @a = create_team(@cup, 'Alpha')
      @b = create_team(@cup, 'Beta')
    end
  end

  test 'active users are the users with predictions in the cup' do
    alice = create_user('alice')
    create_user('bob')
    create_prediction(create_match(@cup, @a, @b), alice, 1, 0)
    assert_equal [alice.id], @cup.active_users.pluck(:id)
    assert_equal 1, @cup.active_users_count
    other = create_cup
    assert_equal 0, other.active_users_count
  end

  test 'available_team_list marks teams already added' do
    data = { 'teams' => [{ 'id' => 1, 'name' => 'Alpha', 'coach' => { 'name' => 'Ann' } },
                         { 'id' => 2, 'name' => 'Gamma' }] }
    FootballData.stub :get, data do
      list = @cup.available_team_list
      assert_equal [true, false], list.map { |t| t[:status] }
      assert_equal 'Ann', list.first[:coach]
      assert_equal 'No Coach Listed', list.last[:coach]
    end
  end

  test 'available_team_list is empty when the API fails' do
    FootballData.stub :get, nil do
      assert_equal [], @cup.available_team_list
    end
  end

  test 'available_match_list keeps only scheduled matches and marks added ones' do
    data = { 'matches' => [
      { 'id' => 1, 'status' => 'TIMED', 'utcDate' => '2026-06-12T18:00:00Z',
        'homeTeam' => { 'id' => 1, 'name' => 'Alpha' }, 'awayTeam' => { 'id' => 2, 'name' => 'Beta' } },
      { 'id' => 2, 'status' => 'FINISHED', 'utcDate' => '2026-06-10T18:00:00Z',
        'homeTeam' => { 'id' => 1, 'name' => 'Alpha' }, 'awayTeam' => { 'id' => 2, 'name' => 'Beta' } },
      { 'id' => 3, 'status' => 'TIMED', 'utcDate' => '2026-06-13T18:00:00Z',
        'homeTeam' => { 'id' => nil, 'name' => nil }, 'awayTeam' => { 'id' => 2, 'name' => 'Beta' } }
    ] }
    create_match(@cup, @a, @b)
    FootballData.stub :get, data do
      list = @cup.available_match_list
      assert_equal [1], list.map { |m| m[:id] }
      assert list.first[:status]
    end
  end

  test 'available lists are memoized' do
    calls = 0
    counter = ->(*) { calls += 1; { 'teams' => [] } }
    FootballData.stub :get, counter do
      2.times { @cup.available_team_list }
    end
    assert_equal 1, calls
  end

  test 'update_result makes one request for all pending matches' do
    pending = [create_match(@cup, @a, @b, time: 1.hour.ago), create_match(@cup, @b, @a, time: 2.hours.ago)]
    pending.each { |m| m.update_columns(updated_at: 5.minutes.ago) }
    create_match(@cup, @a, @b)
    calls = 0
    response = { 'matches' => [
      { 'status' => 'FINISHED', 'homeTeam' => { 'name' => 'Alpha' }, 'awayTeam' => { 'name' => 'Beta' },
        'score' => { 'fullTime' => { 'home' => 1, 'away' => 0 } } },
      { 'status' => 'FINISHED', 'homeTeam' => { 'name' => 'Beta' }, 'awayTeam' => { 'name' => 'Alpha' },
        'score' => { 'fullTime' => { 'home' => 2, 'away' => 2 } } }
    ] }
    FootballData.stub :get, ->(*) { calls += 1; response } do
      @cup.update_result
    end
    assert_equal 1, calls
    assert pending.all? { |m| m.reload.closed? }
  end

  test 'update_result does not call the API when nothing is pending' do
    create_match(@cup, @a, @b)
    FootballData.stub :get, ->(*) { flunk 'API must not be called' } do
      @cup.update_result
    end
  end

  test 'recently updated matches are not refreshed' do
    match = create_match(@cup, @a, @b, time: 1.hour.ago)
    FootballData.stub :get, ->(*) { flunk 'API must not be called' } do
      @cup.update_result
    end
    assert_not match.reload.closed?
  end
end
