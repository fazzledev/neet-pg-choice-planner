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

ActiveRecord::Schema[8.1].define(version: 2026_10_19_191630) do
  create_table "choice_lists", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "counselling_id", null: false
    t.integer "revision", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["counselling_id"], name: "index_choice_lists_on_counselling_id"
    t.index ["user_id", "counselling_id"], name: "index_choice_lists_on_user_id_and_counselling_id", unique: true
    t.index ["user_id"], name: "index_choice_lists_on_user_id"
  end

  create_table "choices", force: :cascade do |t|
    t.integer "counselling_id", null: false
    t.integer "institute_id", null: false
    t.integer "program_id", null: false
    t.string "quota", null: false
    t.integer "sr"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["counselling_id"], name: "index_choices_on_counselling_id"
    t.index ["institute_id", "program_id", "quota"], name: "index_choices_on_institute_id_and_program_id_and_quota", unique: true
    t.index ["institute_id"], name: "index_choices_on_institute_id"
    t.index ["program_id"], name: "index_choices_on_program_id"
  end

  create_table "counsellings", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_counsellings_on_slug", unique: true
  end

  create_table "institute_contacts", force: :cascade do |t|
    t.string "institute_code", null: false
    t.string "confidence"
    t.date "researched_on"
    t.json "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["institute_code"], name: "index_institute_contacts_on_institute_code", unique: true
  end

  create_table "institutes", force: :cascade do |t|
    t.integer "counselling_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "address"
    t.string "type_code"
    t.string "type_name"
    t.string "state"
    t.boolean "state_doubtful", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["counselling_id", "code"], name: "index_institutes_on_counselling_id_and_code", unique: true
    t.index ["counselling_id"], name: "index_institutes_on_counselling_id"
  end

  create_table "picks", force: :cascade do |t|
    t.integer "choice_list_id", null: false
    t.integer "choice_id", null: false
    t.integer "position", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["choice_id"], name: "index_picks_on_choice_id"
    t.index ["choice_list_id", "choice_id"], name: "index_picks_on_choice_list_id_and_choice_id", unique: true
    t.index ["choice_list_id", "position"], name: "index_picks_on_choice_list_id_and_position", unique: true
    t.index ["choice_list_id"], name: "index_picks_on_choice_list_id"
  end

  create_table "programs", force: :cascade do |t|
    t.integer "counselling_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "course", null: false
    t.string "speciality", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["counselling_id", "code"], name: "index_programs_on_counselling_id_and_code", unique: true
    t.index ["counselling_id"], name: "index_programs_on_counselling_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.integer "choice_list_id", null: false
    t.string "label"
    t.json "picks", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "session_id"
    t.index ["choice_list_id"], name: "index_snapshots_on_choice_list_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.boolean "admin", default: false, null: false
    t.string "roll_number"
    t.integer "sign_in_version", default: 0, null: false
    t.datetime "last_signed_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sign_in_link_sent_at"
    t.boolean "added_by_admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "choice_lists", "counsellings"
  add_foreign_key "choice_lists", "users"
  add_foreign_key "choices", "counsellings"
  add_foreign_key "choices", "institutes"
  add_foreign_key "choices", "programs"
  add_foreign_key "institutes", "counsellings"
  add_foreign_key "picks", "choice_lists"
  add_foreign_key "picks", "choices"
  add_foreign_key "programs", "counsellings"
  add_foreign_key "sessions", "users"
  add_foreign_key "snapshots", "choice_lists"
end
