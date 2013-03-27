# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 17) do

  create_table "audits", :force => true do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "changes"
    t.integer  "version",        :default => 0
    t.datetime "created_at"
  end

  add_index "audits", ["auditable_id", "auditable_type"], :name => "auditable_index"
  add_index "audits", ["created_at"], :name => "index_audits_on_created_at"
  add_index "audits", ["user_id", "user_type"], :name => "user_index"

  create_table "control_panels", :force => true do |t|
    t.integer  "user_id"
    t.integer  "project_id"
    t.integer  "customer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "control_panels_tasks", :id => false, :force => true do |t|
    t.integer "control_panel_id"
    t.integer "task_id"
  end

  add_index "control_panels_tasks", ["control_panel_id"], :name => "index_control_panels_tasks_on_control_panel_id"
  add_index "control_panels_tasks", ["task_id", "control_panel_id"], :name => "index_control_panels_tasks_on_task_id_and_control_panel_id"

  create_table "customers", :force => true do |t|
    t.boolean  "active",       :default => true, :null => false
    t.string   "title",                          :null => false
    t.string   "code"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version", :default => 0
  end

  create_table "open_id_authentication_associations", :force => true do |t|
    t.integer "issued"
    t.integer "lifetime"
    t.string  "handle"
    t.string  "assoc_type"
    t.binary  "server_url"
    t.binary  "secret"
  end

  create_table "open_id_authentication_nonces", :force => true do |t|
    t.integer "timestamp",  :null => false
    t.string  "server_url", :null => false
    t.string  "salt",       :null => false
  end

  create_table "projects", :force => true do |t|
    t.integer  "customer_id"
    t.boolean  "active",       :default => true, :null => false
    t.string   "title",                          :null => false
    t.string   "code"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version", :default => 0
  end

  create_table "tasks", :force => true do |t|
    t.integer  "project_id"
    t.boolean  "active",       :default => true, :null => false
    t.string   "title",                          :null => false
    t.string   "code"
    t.text     "description"
    t.decimal  "duration",                       :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version", :default => 0
    t.boolean  "billable",     :default => true
  end

  create_table "tasks_users", :id => false, :force => true do |t|
    t.integer "task_id"
    t.integer "user_id"
  end

  add_index "tasks_users", ["task_id"], :name => "index_tasks_users_on_task_id"
  add_index "tasks_users", ["user_id", "task_id"], :name => "index_tasks_users_on_user_id_and_task_id"

  create_table "timesheet_rows", :force => true do |t|
    t.integer  "timesheet_id", :null => false
    t.integer  "task_id",      :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  create_table "timesheets", :force => true do |t|
    t.integer  "user_id",                         :null => false
    t.integer  "week_number",                     :null => false
    t.integer  "year",                            :null => false
    t.text     "description"
    t.boolean  "committed",    :default => false, :null => false
    t.datetime "committed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version", :default => 0
  end

  create_table "users", :force => true do |t|
    t.text     "identity_url",                     :null => false
    t.text     "name",                             :null => false
    t.text     "email",                            :null => false
    t.string   "code"
    t.string   "user_type",                        :null => false
    t.boolean  "active",         :default => true, :null => false
    t.datetime "last_committed"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version",   :default => 0
  end

  create_table "work_packets", :force => true do |t|
    t.integer  "timesheet_row_id", :null => false
    t.integer  "day_number",       :null => false
    t.decimal  "worked_hours",     :null => false
    t.text     "description"
    t.datetime "date",             :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
