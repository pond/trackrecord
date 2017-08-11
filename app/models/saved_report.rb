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

  audited( {
    :except => [
      :lock_version,
      :updated_at,
      :created_at,
      :id
    ]
  } )

  DEFAULT_SORT_COLUMN    = 'updated_at'
  DEFAULT_SORT_DIRECTION = 'DESC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

  USED_RANGE_COLUMN      = 'updated_at' # For Rangeable base class

  # Relationships

  belongs_to              :user

  has_and_belongs_to_many :active_tasks,
                          {
                            :join_table => :saved_reports_active_tasks,
                            :class_name => 'Task'
                          },
                          -> { readonly() }

  has_and_belongs_to_many :inactive_tasks,
                          {
                            :join_table => :saved_reports_inactive_tasks,
                            :class_name => 'Task'
                          },
                          -> { readonly() }

  has_and_belongs_to_many :reportable_users,
                          {
                            :join_table => :saved_reports_reportable_users,
                            :class_name => 'User'
                          },
                          -> { readonly() }

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

  validates_presence_of  :user_id

  validates_inclusion_of :frequency,           :in => 0...TrackRecordReport::Report::FREQUENCY.length

  validates_inclusion_of :task_filter,         :in => TASK_FILTER_VALUES
  validates_inclusion_of :customer_sort_field, :in => CUSTOMER_SORT_FIELD_VALUES
  validates_inclusion_of :project_sort_field,  :in => PROJECT_SORT_FIELD_VALUES
  validates_inclusion_of :task_sort_field,     :in => TASK_SORT_FIELD_VALUES
  validates_inclusion_of :task_grouping,       :in => TASK_GROUPING_VALUES

  # Return (and cache) a TrackRecordReport::Report instance based on the
  # attributes of this SavedReport model instance. The result is cached for
  # later access within the current request. If you alter attribute values,
  # pass 'true' on entry to force a refresh of the cache and update the
  # TrackRecordReport::Report instance.
  #
  # Optionally, pass in a user. Without this, the saved report's own user
  # details will be used for task filtering and so-on. If you allow another
  # user to view someone else's report, then you will want to pass in that
  # other user's details, since that user may be subject to different
  # restrictions (in particular, differing permitted task lists).
  #
  def generate_report( flush_cache = false, viewing_user = user )

    if ( @report.nil? || flush_cache )

      # The TrackRecord internal Report object can be created from this
      # instance's attributes directly, except for many-to-many relationships,
      # which are not exposed in that hash and must be assigned manually.

      @report                     = TrackRecordReport::Report.new( viewing_user, attributes() )

      @report.title               = title
      @report.active_task_ids     = active_task_ids
      @report.inactive_task_ids   = inactive_task_ids
      @report.reportable_user_ids = reportable_user_ids
    end

    # Sneakily in passing attempt to update our cached start and end ranges

    update_cached_ranges( @report )

    @report
  end

  # Overload default attribute accessors to provide more meaningful values for
  # start and end ranges (see private method "update_cached_ranges" for the
  # other half of this from an implementation standpoint, if interested).
  #
  # Each returns either a Date for a fixed report start or end date, or a
  # symbol - ":all" indicates start-or-end-of-all-time, while symbols starting
  # with 'last', 'this' or 'two' and ending in '_month' or '_week' refer to
  # last month/week, this month/week or two months/weeks ago, respectively
  # (e.g. ":two_week", ":last_month").

  def range_start_cache
    raw_attr_val = self[ :range_start_cache ]
    CACHED_REVERSE_RANGE_MAP[ raw_attr_val ] || raw_attr_val
  end

  def range_end_cache
    raw_attr_val = self[ :range_end_cache ]
    CACHED_REVERSE_RANGE_MAP[ raw_attr_val ] || raw_attr_val
  end

  # Is the given user permitted to do anything with this report?
  # A shared report can be viewed by anyone, privileged users can
  # view any report and of course the report's owner can view it.
  #
  def is_permitted_for?( comparison_user )
    shared? or comparison_user == user or comparison_user.privileged?
  end

  # Is the given user permitted to update this report? Only report
  # owners or administrators can do so.

  def can_be_modified_by?( comparison_user )
    comparison_user == user or comparison_user.admin?
  end

private # =====================================================================

  # Range maps and "update_cached_ranges": An effective hack to map a Report's
  # indication of date range to a Date value which can be stored in the
  # database. Store very early dates, so that people can ask the database to
  # sort on the cache values and get relative-style date reports collected
  # together. Yes, this does mean that attempts to report time in early January
  # of the year 4000 would result in confusion, but only confusion for views
  # which use the cached range values for sorting. They're not used for any
  # report mathematics calculations. In practice only the 'Saved Reports' index
  # view would do the wrong thing; and it's something of an edge use case :-)
  #
  # A high future date is used rather than a low past date (e.g. the 1900s) so
  # that sorting makes sense. If you wanted to see your most recent reports,
  # for example, you'd sort descending by start date. But chances are any of
  # the relative dates are likely to be the most recent, or a good enough
  # approximation, so they should show up first in a descending sort.
  #
  # It would theoretically be possible to sweep a user's saved reports at an
  # "appropriate moment" (e.g. rendering of the index view) and update all of
  # the cached dates to *actual* values and give a true accurate sort, but
  # that's an unbounded performance problem and not really necessary.

  CACHED_RANGE_MAP = {
    :all        => Date.new( 4000, 1, 1 ),
    :two_month  => Date.new( 4000, 1, 2 ),
    :last_month => Date.new( 4000, 1, 3 ),
    :this_month => Date.new( 4000, 1, 4 ),
    :two_week   => Date.new( 4000, 1, 5 ),
    :last_week  => Date.new( 4000, 1, 6 ),
    :this_week  => Date.new( 4000, 1, 7 )
  }

  CACHED_REVERSE_RANGE_MAP = Hash[ CACHED_RANGE_MAP.map( &:reverse ) ]

  # Based on the *given* report (the possibly-set internal copy of '@report'
  # is intentionally not consulted so the caller is responsible for thinking
  # about whether or not the report is up to date or needs regenerating),
  # update start and end cache values, quietly saving this object if need be.
  # Fixed reporting dates are stored as such. Relative dates such as "all
  # time" or "last week" are stored using the CACHED_RANGE_MAP dates defined
  # above, under the rationale described above. Custom public accessors
  # written earlier in this file map the values back again, using the
  # CACHED_REVERSE_RANGE_MAP.
  #
  # Returns 'true' for success (report updated and saved, or report cache
  # was already up to date) or 'false' for failure (report save attempt
  # failed for any reason - validation, database exception, whatever).
  #
  def update_cached_ranges( report )
    start_cache = CACHED_RANGE_MAP[ report.cacheable_start_indicator ] || report.cacheable_start_indicator
    end_cache   = CACHED_RANGE_MAP[ report.cacheable_end_indicator   ] || report.cacheable_end_indicator

    if ( start_cache != self.range_start_cache || end_cache != self.range_end_cache )
      self.range_start_cache = start_cache
      self.range_end_cache   = end_cache

      begin
        self.save # Return true/false directly, no validation exceptions...
      rescue
        false # ...but might still get DB exceptions, so catch those
      end

    else
      true # No change => no need to re-save => return as if saving succeeded

    end
  end
end
