########################################################################
# File::    saved_report.rb
# (C)::     Hipposoft 2011
#
# Purpose:: Describe and record all parameters needed to generate
#           reports.
# ----------------------------------------------------------------------
#           13-Oct-2011 (ADH): Created.
########################################################################

class SavedReport < Rangeable

  DEFAULT_SORT_COLUMN    = 'updated_at'
  DEFAULT_SORT_DIRECTION = 'DESC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

  USED_RANGE_COLUMN      = 'updated_at' # For Rangeable base class

  # Relationships and security

  belongs_to              :user
  attr_protected          :user_id

  has_and_belongs_to_many :active_tasks,     :join_table => :saved_reports_active_tasks,
                                             :class_name => 'Task',
                                             :readonly   => true

  has_and_belongs_to_many :inactive_tasks,   :join_table => :saved_reports_inactive_tasks,
                                             :class_name => 'Task',
                                             :readonly   => true

  has_and_belongs_to_many :reportable_users, :join_table => :saved_reports_reportable_users,
                                             :class_name => 'User',
                                             :readonly   => true

  # Various constants used by the "20111013142252_add_saved_reports_support.rb"
  # migration file and various pieces of application code

  TITLE_LIMIT                    = 128

  TASK_FILTER_LIMIT              = 16
  TASK_FILTER_VALUES             = %w{ all billable non_billable }
  TASK_FILTER_ALL,
  TASK_FILTER_BILLABLE,
  TASK_FILTER_NON_BILLABLE       = TASK_FILTER_VALUES

  CUSTOMER_SORT_FIELD_LIMIT      = 16
  CUSTOMER_SORT_FIELD_VALUES     = %w{ title code created_at }
  CUSTOMER_SORT_FIELD_TITLE,
  CUSTOMER_SORT_FIELD_CODE,
  CUSTOMER_SORT_FIELD_CREATED_AT = CUSTOMER_SORT_FIELD_VALUES

  PROJECT_SORT_FIELD_LIMIT       = 16
  PROJECT_SORT_FIELD_VALUES      = %w{ title code created_at }
  PROJECT_SORT_FIELD_TITLE,
  PROJECT_SORT_FIELD_CODE,
  PROJECT_SORT_FIELD_CREATED_AT  = PROJECT_SORT_FIELD_VALUES

  TASK_SORT_FIELD_LIMIT          = 16
  TASK_SORT_FIELD_VALUES         = %w{ title code created_at }
  TASK_SORT_FIELD_TITLE,
  TASK_SORT_FIELD_CODE,
  TASK_SORT_FIELD_CREATED_AT     = TASK_SORT_FIELD_VALUES

  TASK_GROUPING_LIMIT            = 16
  TASK_GROUPING_VALUES           = %w{ default billable active both }
  TASK_GROUPING_DEFAULT,
  TASK_GROUPING_BILLABLE,
  TASK_GROUPING_ACTIVE,
  TASK_GROUPING_BOTH             = TASK_GROUPING_VALUES

  # Validations

  validates_inclusion_of :frequency,           :in => 0...TrackRecordReport::Report::FREQUENCY.length

  validates_inclusion_of :task_filter,         :in => TASK_FILTER_VALUES
  validates_inclusion_of :customer_sort_field, :in => CUSTOMER_SORT_FIELD_VALUES
  validates_inclusion_of :project_sort_field,  :in => PROJECT_SORT_FIELD_VALUES
  validates_inclusion_of :task_sort_field,     :in => TASK_SORT_FIELD_VALUES
  validates_inclusion_of :task_grouping,       :in => TASK_GROUPING_VALUES

  # Return (and cache) a TrackRecordReport::Report instance based on the
  # attributes of this SavedReport model instance. The result is cached for
  # later access. If you alter attribute values, pass 'true' on entry to
  # force a refresh of the cache and update the TrackRecordReport::Report
  # instance.
  #
  def generate_report( flush_cache = false )
    if ( @report.nil? || flush_cache )
      # The TrackRecord internal Report object can be created from this
      # instance's attributes directly, except for many-to-many relationships,
      # which are not exposed in that hash and must be assigned manually.

      @report                     = TrackRecordReport::Report.new( user, attributes() )
      @report.active_task_ids     = active_task_ids
      @report.inactive_task_ids   = inactive_task_ids
      @report.reportable_user_ids = reportable_user_ids
    end

    @report
  end
end
