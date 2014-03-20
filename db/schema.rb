# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20131011010129) do

  create_table "audits", :force => true do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "audited_changes"
    t.integer  "version",         :default => 0
    t.datetime "created_at"
    t.string   "comment"
    t.string   "remote_address"
    t.integer  "associated_id"
    t.string   "associated_type"
  end

  add_index "audits", ["associated_id", "associated_type"], :name => "associated_index"
  add_index "audits", ["auditable_id", "auditable_type"], :name => "auditable_index"
  add_index "audits", ["created_at"], :name => "index_audits_on_created_at"
  add_index "audits", ["user_id", "user_type"], :name => "user_index"

  create_table "control_panels", :force => true do |t|
    t.integer  "user_id"
    t.integer  "project_id"
    t.integer  "customer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "preferences"
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

  create_table "saved_reports", :force => true do |t|
    t.integer  "user_id"
    t.string   "title",                 :limit => 128
    t.boolean  "shared",                               :default => false
    t.date     "range_start"
    t.string   "range_week_start",      :limit => 7
    t.string   "range_month_start",     :limit => 7
    t.date     "range_end"
    t.string   "range_week_end",        :limit => 7
    t.string   "range_month_end",       :limit => 7
    t.date     "range_start_cache"
    t.date     "range_end_cache"
    t.integer  "frequency",                            :default => 0
    t.string   "task_filter",           :limit => 16,  :default => "all"
    t.boolean  "include_totals",                       :default => true
    t.boolean  "include_committed",                    :default => false
    t.boolean  "include_not_committed",                :default => false
    t.boolean  "exclude_zero_rows",                    :default => false
    t.boolean  "exclude_zero_cols",                    :default => false
    t.string   "customer_sort_field",   :limit => 16,  :default => "title"
    t.string   "project_sort_field",    :limit => 16,  :default => "title"
    t.string   "task_sort_field",       :limit => 16,  :default => "code"
    t.string   "task_grouping",         :limit => 16,  :default => "default"
    t.datetime "created_at",                                                  :null => false
    t.datetime "updated_at",                                                  :null => false
    t.string   "range_one_month",       :limit => 7
    t.string   "range_one_week",        :limit => 7
    t.boolean  "user_details"
    t.integer  "lock_version",                         :default => 0
  end

  add_index "saved_reports", ["user_id"], :name => "index_saved_reports_on_user_id"

  create_table "saved_reports_active_tasks", :id => false, :force => true do |t|
    t.integer "saved_report_id"
    t.integer "task_id"
  end

  add_index "saved_reports_active_tasks", ["saved_report_id"], :name => "index_saved_reports_active_tasks_on_saved_report_id"
  add_index "saved_reports_active_tasks", ["task_id"], :name => "index_saved_reports_active_tasks_on_task_id"

  create_table "saved_reports_inactive_tasks", :id => false, :force => true do |t|
    t.integer "saved_report_id"
    t.integer "task_id"
  end

  add_index "saved_reports_inactive_tasks", ["saved_report_id"], :name => "index_saved_reports_inactive_tasks_on_saved_report_id"
  add_index "saved_reports_inactive_tasks", ["task_id"], :name => "index_saved_reports_inactive_tasks_on_task_id"

  create_table "saved_reports_reportable_users", :id => false, :force => true do |t|
    t.integer "saved_report_id"
    t.integer "user_id"
  end

  add_index "saved_reports_reportable_users", ["saved_report_id"], :name => "index_saved_reports_reportable_users_on_saved_report_id"
  add_index "saved_reports_reportable_users", ["user_id"], :name => "index_saved_reports_reportable_users_on_user_id"

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
    t.integer  "user_id",                                          :null => false
    t.integer  "week_number",                                      :null => false
    t.integer  "year",                                             :null => false
    t.text     "description"
    t.boolean  "committed",                     :default => false, :null => false
    t.datetime "committed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lock_version",                  :default => 0
    t.datetime "start_day_cache"
    t.string   "auto_sort",       :limit => 16
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
    t.date     "date",             :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
