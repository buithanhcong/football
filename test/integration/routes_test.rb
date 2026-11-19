require 'test_helper'

class RoutesTest < ActionDispatch::IntegrationTest
  test 'named route helpers keep their URLs' do
    {
      root_path => '/',
      cups_path => '/cups',
      new_cup_path => '/cups/new',
      edit_cup_path(3) => '/cups/3/edit',
      cup_path(3) => '/cups/3',
      rand_grp_cup_path(3) => '/cups/3/rgp',
      calc_grp_score_cup_path(3) => '/cups/3/cgp',
      teams_path(cup_id: 2) => '/teams/2',
      new_team_path(cup_id: 2) => '/teams/new/2',
      edit_team_path(4) => '/teams/4/edit',
      team_path(4) => '/teams/4/show',
      delete_team_path(4) => '/teams/4',
      matches_path(cup_id: 2) => '/matches/2',
      new_match_path(cup_id: 2) => '/matches/new/2',
      edit_match_path(5) => '/matches/5/edit',
      match_path(5) => '/matches/5/show',
      delete_match_path(5) => '/matches/5',
      cal_scr_match_path(7) => '/matches/rcr/7',
      predictions_path(cup_id: 2) => '/predictions/2',
      new_prediction_path(cup_id: 2) => '/predictions/new/2',
      edit_prediction_path(6) => '/predictions/6/edit',
      prediction_path(6) => '/predictions/6/show',
      delete_prediction_path(6) => '/predictions/6',
      users_index_path => '/users/index',
      leader_board_path(cup_id: 1, stage: 'group') => '/users/index/1/group',
      users_list_path(cup_id: 1) => '/users/list/1',
      user_reset_pass_path(cup_id: 1, u_id: 2) => '/users/reset_pass/1/2',
      user_remove_cup_path(cup_id: 1, u_id: 2) => '/users/remove_cup/1/2'
    }.each { |actual, expected| assert_equal expected, actual }
  end

  test 'cups resource routes' do
    assert_routing({ method: 'get', path: '/cups' }, controller: 'cups', action: 'index')
    assert_routing({ method: 'post', path: '/cups' }, controller: 'cups', action: 'create')
    assert_routing({ method: 'get', path: '/cups/new' }, controller: 'cups', action: 'new')
    assert_routing({ method: 'get', path: '/cups/1' }, controller: 'cups', action: 'show', cup_id: '1')
    assert_routing({ method: 'delete', path: '/cups/1' }, controller: 'cups', action: 'destroy', cup_id: '1')
    assert_recognizes({ controller: 'cups', action: 'update', cup_id: '1' }, method: :patch, path: '/cups/1')
    assert_recognizes({ controller: 'cups', action: 'update', cup_id: '1' }, method: :put, path: '/cups/1')
  end

  test 'state changing actions are not GET routes' do
    assert_routing({ method: 'post', path: '/cups/1/rgp' }, controller: 'cups', action: 'rnd_grp_pre', cup_id: '1')
    assert_routing({ method: 'post', path: '/cups/1/cgp' }, controller: 'cups', action: 'cal_grp_scr', cup_id: '1')
    assert_routing({ method: 'post', path: '/matches/rcr/1' }, controller: 'matches', action: 'cal_scr', match_id: '1')
    assert_routing({ method: 'post', path: '/users/reset_pass/1/2' },
                   controller: 'users', action: 'reset_pass', cup_id: '1', u_id: '2')
    assert_routing({ method: 'delete', path: '/users/remove_cup/1/2' },
                   controller: 'users', action: 'remove_cup', cup_id: '1', u_id: '2')
    %w[/cups/1/rgp /cups/1/cgp /matches/rcr/1 /users/reset_pass/1/2].each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path, method: :get)
      end
    end
  end

  test 'update routes accept PATCH and PUT' do
    { 'teams' => 'team_id', 'matches' => 'match_id', 'predictions' => 'prediction_id' }.each do |name, param|
      %i[patch put].each do |verb|
        assert_recognizes({ controller: name, action: 'update', param.to_sym => '9' }, method: verb, path: "/#{name}/9/show")
      end
    end
  end
end
