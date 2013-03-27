class AddSavedReportsSupport < ActiveRecord::Migration
  def up
    create_table :saved_reports do |t|

      # Information used to manage saved reports.

      t.belongs_to  :user
      t.string      :title,  :limit => SavedReport::TITLE_LIMIT
      t.boolean     :shared, :default => false

      # Information used to generate actual reports, where a nil value has
      # an implicit default meaning.
      #
      # Range week/month start/end strings are of the form "YYYY_WW" or
      # "YYYY_DD", so have a known fixed maximum size.
      #
      # The cache columns contain the consolidated equivalent of the values
      # set in the six optional range mechanisms. Consolidation is done via
      # TrackRecordReport::Report by giving a Report the three ranges and
      # asking it for the resulting equivalent minimum and maximum dates.

      t.date        :range_start
      t.string      :range_week_start,  :limit => 7
      t.string      :range_month_start, :limit => 7

      t.date        :range_end
      t.string      :range_week_end,    :limit => 7
      t.string      :range_month_end,   :limit => 7

      t.date        :range_start_cache
      t.date        :range_end_cache

      # Information used to generate actual reports, where explicit default
      # values are used.

      t.integer     :frequency,             :default => 0 # See TrackRecordReport's Report::FREQUENCY

      t.string      :task_filter,           :limit   => SavedReport::TASK_FILTER_LIMIT,
                                            :default => SavedReport::TASK_FILTER_ALL

      t.boolean     :include_totals,        :default => true
      t.boolean     :include_committed,     :default => false
      t.boolean     :include_not_committed, :default => false
      t.boolean     :exclude_zero_rows,     :default => false
      t.boolean     :exclude_zero_cols,     :default => false

      t.string      :customer_sort_field,   :limit   => SavedReport::CUSTOMER_SORT_FIELD_LIMIT,
                                            :default => SavedReport::CUSTOMER_SORT_FIELD_TITLE
      t.string      :project_sort_field,    :limit   => SavedReport::PROJECT_SORT_FIELD_LIMIT,
                                            :default => SavedReport::PROJECT_SORT_FIELD_TITLE
      t.string      :task_sort_field,       :limit   => SavedReport::TASK_SORT_FIELD_LIMIT,
                                            :default => SavedReport::TASK_SORT_FIELD_CODE
      t.string      :task_grouping,         :limit   => SavedReport::TASK_GROUPING_LIMIT,
                                            :default => SavedReport::TASK_GROUPING_DEFAULT

      t.timestamps

      # Active task, inactive task and calculate-for-user lists are handled
      # using HABTM relationships so use join tables defined below.

    end

    add_index :saved_reports, :user_id

    create_table :saved_reports_active_tasks, :id => false do |t|
      t.integer :saved_report_id
      t.integer :task_id
    end

    add_index :saved_reports_active_tasks, :saved_report_id
    add_index :saved_reports_active_tasks, :task_id

    create_table :saved_reports_inactive_tasks, :id => false do |t|
      t.integer :saved_report_id
      t.integer :task_id
    end

    add_index :saved_reports_inactive_tasks, :saved_report_id
    add_index :saved_reports_inactive_tasks, :task_id

    create_table :saved_reports_reportable_users, :id => false do |t|
      t.integer :saved_report_id
      t.integer :user_id
    end

    add_index :saved_reports_reportable_users, :saved_report_id
    add_index :saved_reports_reportable_users, :user_id
  end

  def down
    drop_table :saved_reports
    drop_table :saved_reports_active_tasks
    drop_table :saved_reports_inactive_tasks
    drop_table :saved_reports_reportable_users
  end
end
