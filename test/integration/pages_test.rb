require 'test_helper'

class PagesTest < ActionDispatch::IntegrationTest
  setup do
    @cup = create_cup(name: 'Euro Test')
    @a = create_team(@cup, 'Alpha')
    @b = create_team(@cup, 'Beta')
    @alice = create_user('alice')
    @bob = create_user('bob')
    @admin = create_user('admin', admin: true)
    @group = create_match(@cup, @a, @b)
    @alice_group = create_prediction(@group, @alice, 2, 1)
    create_prediction(@group, @bob, 0, 0)
    finish_match(@group, mainscore1: 2, mainscore2: 1)
    @knockout = create_match(@cup, @a, @b, knockout: true)
    @alice_knockout = create_prediction(@knockout, @alice, 1, 0)
    finish_match(@knockout, mainscore1: 1, mainscore2: 0)
    @upcoming = create_match(@cup, @b, @a)
    @alice_upcoming = create_prediction(@upcoming, @alice, 0, 1)
  end

  test 'anonymous users are sent to the login page' do
    get cups_path
    assert_redirected_to new_user_session_path
  end

  test 'player pages render' do
    sign_in @alice
    [cups_path, cup_path(@cup), teams_path(cup_id: @cup.id), team_path(@a),
     matches_path(cup_id: @cup.id), match_path(@group), match_path(@upcoming),
     predictions_path(cup_id: @cup.id), prediction_path(@alice_group),
     new_prediction_path(cup_id: @cup.id), edit_prediction_path(@alice_upcoming),
     leader_board_path(cup_id: @cup.id, stage: 'group'),
     leader_board_path(cup_id: @cup.id, stage: 'knockout')].each do |path|
      get path
      assert_response :success, "GET #{path} returned #{response.status}"
    end
  end

  test 'group leaderboard lists the players' do
    sign_in @alice
    get leader_board_path(cup_id: @cup.id, stage: 'group')
    assert_select 'th', text: 'alice'
    assert_select 'th', text: 'bob'
    assert_select 'th', text: 'admin', count: 0
  end

  test 'knockout leaderboard only lists players with closed knockout predictions' do
    sign_in @alice
    get leader_board_path(cup_id: @cup.id, stage: 'knockout')
    assert_select 'th', text: 'alice'
    assert_select 'th', text: 'bob', count: 0
  end

  test 'cup page shows my prediction for the next match' do
    sign_in @alice
    get cup_path(@cup)
    assert_response :success
    assert_select 'td', text: '0 - 1'
  end

  test 'match page lists everybody once the match has started' do
    sign_in @bob
    get match_path(@group)
    assert_select 'td', text: 'alice'
    get match_path(@upcoming)
    assert_select 'td', text: 'alice', count: 0
  end

  test 'admin pages render' do
    sign_in @admin
    FootballData.stub :get, nil do
      [users_list_path(cup_id: @cup.id), new_team_path(cup_id: @cup.id), new_match_path(cup_id: @cup.id),
       new_cup_path, edit_cup_path(@cup), edit_team_path(@a), edit_match_path(@group)].each do |path|
        get path
        assert_response :success, "GET #{path} returned #{response.status}"
      end
    end
  end

  test 'players cannot reset passwords' do
    sign_in @alice
    post user_reset_pass_path(cup_id: @cup.id, u_id: @bob.id)
    assert_redirected_to root_path
    assert @bob.reload.valid_password?('password123')
  end

  test 'admin reset gives a random password' do
    sign_in @admin
    post user_reset_pass_path(cup_id: @cup.id, u_id: @bob.id)
    assert_redirected_to users_list_url(cup_id: @cup.id)
    new_password = flash[:notice][/reset to: (\w+)/, 1]
    assert_equal 10, new_password.to_s.length
    assert_not @bob.reload.valid_password?('password123')
    assert @bob.valid_password?(new_password)
  end

  test 'players cannot remove users from a cup' do
    sign_in @alice
    assert_no_difference -> { Prediction.count } do
      delete user_remove_cup_path(cup_id: @cup.id, u_id: @bob.id)
    end
    assert_redirected_to root_path
  end

  test 'admin removes the group predictions of a user' do
    sign_in @admin
    assert_difference -> { Prediction.count }, -1 do
      delete user_remove_cup_path(cup_id: @cup.id, u_id: @bob.id)
    end
    assert_redirected_to users_list_url(cup_id: @cup.id)
  end

  test 'only admins can recalculate a match' do
    sign_in @alice
    post cal_scr_match_path(@group)
    assert_redirected_to root_path
    sign_out @alice
    sign_in @admin
    post cal_scr_match_path(@group)
    assert_redirected_to matches_path(cup_id: @cup.id)
  end

  test 'recalculating a match is idempotent' do
    sign_in @admin
    before = [@alice_group.reload.reward, Score.find_by(user: @alice, cup: @cup).score]
    post cal_scr_match_path(@group)
    assert_equal before, [@alice_group.reload.reward, Score.find_by(user: @alice, cup: @cup).score]
  end

  test 'players can create and delete their own prediction' do
    other = create_match(@cup, @a, @b, time: 2.days.from_now)
    sign_in @bob
    assert_difference -> { Prediction.count }, 1 do
      post predictions_path(cup_id: @cup.id), params: { prediction: { match_id: other.id, mainscore1: 1, mainscore2: 1 } }
    end
    prediction = Prediction.find_by(user: @bob, match: other)
    assert_redirected_to prediction_path(prediction)
    assert_difference -> { Prediction.count }, -1 do
      delete delete_prediction_path(prediction)
    end
  end

  test 'players cannot delete other predictions' do
    sign_in @bob
    assert_no_difference -> { Prediction.count } do
      delete delete_prediction_path(@alice_upcoming)
    end
  end
end
