Rails.application.routes.draw do
  devise_for :users

  get 'users/index'
  get    'users/index/:cup_id/:stage'     => 'users#index',      as: :leader_board
  get    'users/list/:cup_id'             => 'users#list',       as: :users_list
  post   'users/reset_pass/:cup_id/:u_id' => 'users#reset_pass', as: :user_reset_pass
  delete 'users/remove_cup/:cup_id/:u_id' => 'users#remove_cup', as: :user_remove_cup

  resource :user, only: [:edit] do
    collection do
      patch 'update_password'
    end
  end

  resources :users do
    member do
      delete :destroy_without_predictions
    end
  end

  resources :cups, param: :cup_id do
    member do
      post :rgp, action: :rnd_grp_pre, as: :rand_grp
      post :cgp, action: :cal_grp_scr, as: :calc_grp_score
    end
  end

  scope controller: :teams do
    get    'teams/:cup_id',       action: :index,   as: :teams
    post   'teams/:cup_id',       action: :create
    get    'teams/new/:cup_id',   action: :new,     as: :new_team
    get    'teams/:team_id/edit', action: :edit,    as: :edit_team
    get    'teams/:team_id/show', action: :show,    as: :team
    patch  'teams/:team_id/show', action: :update
    put    'teams/:team_id/show', action: :update
    delete 'teams/:team_id',      action: :destroy, as: :delete_team
  end

  scope controller: :matches do
    get    'matches/:cup_id',        action: :index,   as: :matches
    post   'matches/:cup_id',        action: :create
    get    'matches/new/:cup_id',    action: :new,     as: :new_match
    get    'matches/:match_id/edit', action: :edit,    as: :edit_match
    get    'matches/:match_id/show', action: :show,    as: :match
    patch  'matches/:match_id/show', action: :update
    put    'matches/:match_id/show', action: :update
    delete 'matches/:match_id',      action: :destroy, as: :delete_match
    post   'matches/rcr/:match_id',  action: :cal_scr, as: :cal_scr_match
  end

  scope controller: :predictions do
    get    'predictions/:cup_id',             action: :index,   as: :predictions
    post   'predictions/:cup_id',             action: :create
    get    'predictions/new/:cup_id',         action: :new,     as: :new_prediction
    get    'predictions/:prediction_id/edit', action: :edit,    as: :edit_prediction
    get    'predictions/:prediction_id/show', action: :show,    as: :prediction
    patch  'predictions/:prediction_id/show', action: :update
    put    'predictions/:prediction_id/show', action: :update
    delete 'predictions/:prediction_id',      action: :destroy, as: :delete_prediction
  end

  root 'cups#index'
end
