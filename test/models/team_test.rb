require 'test_helper'

class TeamTest < ActiveSupport::TestCase
  setup do
    @cup = create_cup
    @a = create_team(@cup, 'Alpha')
    @b = create_team(@cup, 'Beta')
  end

  def play(team1, team2, score1, score2)
    finish_match(create_match(@cup, team1, team2), mainscore1: score1, mainscore2: score2)
  end

  test 'record of a team over played group matches' do
    play(@a, @b, 2, 1)
    play(@b, @a, 1, 1)
    team = Team.find(@a.id)
    assert_equal 2, team.played_rows.size
    assert_equal 1, team.won_matches.size
    assert_equal 1, team.drew_matches.size
    assert_equal 0, team.loss_matches.size
    assert_equal 3, team.goal_for
    assert_equal 2, team.goal_against
    assert_equal 4, team.score
    assert_equal 1, Team.find(@b.id).loss_matches.size
    assert_equal 1, Team.find(@b.id).score
  end

  test 'open and knockout matches are not played group matches' do
    create_match(@cup, @a, @b)
    finish_match(create_match(@cup, @a, @b, knockout: true), mainscore1: 1, mainscore2: 0)
    assert_empty Team.find(@a.id).played_rows
  end

  test 'played_rows can be preloaded' do
    team = Team.find(@a.id)
    team.played_rows = []
    play(@a, @b, 1, 0)
    assert_equal 0, team.goal_for
    assert_equal 1, Team.find(@a.id).goal_for
  end

  test 'remaining matches' do
    play(@a, @b, 1, 0)
    create_match(@cup, @a, @b)
    assert_equal 1, Team.find(@a.id).remain_matches_count
  end

  test 'knockout loser is eliminated' do
    finish_match(create_match(@cup, @a, @b, knockout: true), mainscore1: 1, mainscore2: 0)
    assert Team.find(@a.id).status
    assert_not Team.find(@b.id).status
  end

  test 'logo is fetched for new teams and kept when the lookup fails' do
    cup = create_cup(result_id: 2000)
    FootballData.stub :get, { 'teams' => [{ 'name' => 'Gamma', 'crest' => 'http://logo/g.png' }] } do
      team = create_team(cup, 'Gamma')
      assert_equal 'http://logo/g.png', team.logourl
    end
    FootballData.stub :get, nil do
      team = Team.find_by(name: 'Gamma')
      team.update!(name: 'Gamma FC')
      assert_equal 'http://logo/g.png', team.logourl
    end
  end

  test 'logo is not looked up for manual cups' do
    FootballData.stub :get, ->(*) { flunk 'API must not be called' } do
      assert_equal '', create_team(@cup, 'Zeta').logourl
    end
  end

  test 'score updates do not hit the API' do
    cup = create_cup(result_id: 2000)
    team = FootballData.stub(:get, nil) { create_team(cup, 'Delta') }
    FootballData.stub :get, ->(*) { flunk 'API must not be called' } do
      team.update!(score: 5)
    end
  end
end
