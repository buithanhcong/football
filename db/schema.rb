# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2021_08_10_154955) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cups", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "host"
    t.string "logo"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "result_id"
    t.float "reward_percent"
    t.integer "save_reward"
    t.boolean "is_league", default: false
  end

  create_table "matches", id: :serial, force: :cascade do |t|
    t.integer "team1_id"
    t.integer "team2_id"
    t.integer "mainscore1"
    t.integer "mainscore2"
    t.integer "subscore1"
    t.integer "subscore2"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "status", default: false
    t.datetime "time", precision: nil
    t.integer "cup_id", default: 1
    t.boolean "knockout"
    t.float "prior1"
    t.float "prior2"
    t.integer "penscore1"
    t.integer "penscore2"
    t.integer "fee"
    t.boolean "special_final"
    t.index ["cup_id"], name: "index_matches_on_cup_id"
  end

  create_table "predictions", id: :serial, force: :cascade do |t|
    t.integer "match_id"
    t.integer "user_id"
    t.integer "mainscore1"
    t.integer "mainscore2"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "cup_id"
    t.integer "reward"
    t.index ["cup_id"], name: "index_predictions_on_cup_id"
    t.index ["match_id"], name: "index_predictions_on_match_id"
    t.index ["user_id"], name: "index_predictions_on_user_id"
  end

  create_table "scores", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "cup_id"
    t.integer "score"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "reward"
    t.integer "knockout_reward"
    t.integer "knockout_fee"
    t.index ["cup_id"], name: "index_scores_on_cup_id"
    t.index ["user_id"], name: "index_scores_on_user_id"
  end

  create_table "teams", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "score"
    t.string "coach"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "status", default: true
    t.integer "cup_id", default: 1
    t.string "cup_group", limit: 1
    t.string "logourl", default: ""
    t.index ["cup_id"], name: "index_teams_on_cup_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "admin", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "matches", "cups"
  add_foreign_key "predictions", "cups"
  add_foreign_key "predictions", "matches"
  add_foreign_key "predictions", "users"
  add_foreign_key "scores", "cups"
  add_foreign_key "scores", "users"
  add_foreign_key "teams", "cups"
end
