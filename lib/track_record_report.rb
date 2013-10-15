########################################################################
# File::    track_record_report.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Mixin providing classes which represent all aspects of a
#           TrackRecord report.
# ----------------------------------------------------------------------
#           29-Jun-2008 (ADH): Created.
########################################################################

require 'track_record_sections'

# A container for report code. TrackRecordReport::Report instances are
# passed to generators - see TrackRecordReportGenerator for details.
#
# A compilable Report sets attributes from parameters passed in, which
# might be the result of a Rails form submission for a potentially new
# or edited SavedReport instance - or more commonly, the "attributes()"
# call result on an existing SavedReport instance. Either way, all the
# attributes are copied internally with extra processing and filtering,
# so you can read things like the saved report "range_start_cache" and
# "range_start_cache" attributes, or instead use the compilable report's
# computed "range" property - a Range instance giving the two inclusive
# Dates for the report start and end.
#
# Once compiled with "compile", a report can be queried by first
# iterating over its rows with "each_row". Discover cells within rows
# with "each_cell_for". If parameters tell the report to include per-user
# data during compilation, then for each row call "each_user_on_row" to
# enumerate users with relevant data on that row, then for each such
# user within the row, "each_cell_for_user_on_row" to enumerate the cells
# giving totals for each user in that row and column (you can also do
# this manually with "each_cell_for" and the Cell "user_total" method).
#
# Ranges of columns for an x-axis-is-date report can be iterated over
# with "each_column_range" and human-readable headings generated using
# "column_heading". Overall totals for all rows can be obtained with the
# "each_column_total" iterator. For each object returned, per-user data
# can be discovered via the "user_total" method if required.
#
# A Report mixes in behaviour from TrackRecordSections so that as well as
# providing report data, it provides section and group information with
# per-section/per-section-per-user calculations all integrated. You can
# use the section interface via the report just as you might use the
# interface directly via TrackRecordSections::Sections.
#
# If you want to get the sorted array of tasks a compiled report covers,
# use the "filtered_tasks" property. To see if a report includes per-user
# details, see if the array in its "users" property is empty. If not, the
# list of users with non-zero totals for a compiled report can be found
# in the "filtered_users" array.
#
# Note that if the "filtered_tasks" array is empty after compilation, the
# report determined that it could perform no useful calculations. Proceed
# as if the report was never compiled in the first place - don't attempt
# to iterate over its rows for example - and just let the user know that
# the report is 'empty' / has no useful data.
#
# A Report itself is a calculation object (see the Calculator and
# CalculatorWithUsers classes) and its own committed and not-committed
# hour values represent the overall report total. The rows and cells and
# various other calculated portions are similarly subclassed. Additonally
# a final pass over the report's non-zero hour tasks is made and three
# numbers generated to indicate overall task results: "total_duration" is
# a BigDecimal giving the total task duration (for tasks with that set),
# "total_actual_remaining" is the total duration minus all committed
# hours (only meaningful if all your reported tasks have valid durations)
# and "total_potential_remaining" further subtracts not-committed hours,
# in timesheets which may yet be edited by their owners - hence it is an
# indication of potential, rather than definite remaining time.
#
# For examples of how all this information can be used, along with where
# precalculated total information is stored and how to generate your own
# totals using report calculator objects yourself, examine the CSV
# export code - see TrackRecordReportGenerator::UkOrgPondCSV inside
# <tt>lib/report_generators/track_record_report_generator_uk_org_pond_csv.rb</tt>.
# You can also consult <tt>app/views/reports</tt> partials for various
# report types, though the mixture of ERb code and HTML therein can make
# it harder to see what's going on.
#
# == Database dependence
#
# For information about this, please see the documentation for
# TrackRecordReport::Report and the FREQUENCY constant.
#
module TrackRecordReport

  ###########################################################################
  # Basic object containing a committed and not-committed hour count,
  # with some simple related helper methods.
  #
  # Clients manipulate the committed/not-committed values directly.
  # They're BigDecimals starting at zero. Higher levels of abstraction
  # cause too great a performance hit.
  #
  class Calculator
    attr_accessor :committed
    attr_accessor :not_committed

    def initialize
      @committed = @not_committed = BigDecimal.new( 0 )
    end

    # Returns total worked hours (committed plus not committed).
    #
    def total
      return ( @committed + @not_committed )
    end

    # Returns 'true' if the object records > 0 total hours, else 'false'.
    #
    def has_hours?
      return ( total() > BigDecimal.new( 0 ) )
    end
  end

  ###########################################################################
  # A Calculator subclass which adds support for a hash of per-user
  # Calculator instances accessed via user ID, as a string.
  #
  class CalculatorWithUsers < Calculator
    def initialize
      super()
      @user_totals = {}
    end

    # Return a Calculator object for the given user (as a string database
    # ID), or nil if there is no such user record for this cell.
    #
    def user_total( user_id_str )
      @user_totals[ user_id_str ]
    end

    # Return a Calculator object for the given user (as a string database
    # ID), lazy-creating a new instance if need be.
    #
    def user_total!( user_id_str )
      @user_totals[ user_id_str ] ||= Calculator.new
    end
  end

  ###########################################################################
  # A Cell stores its own total and an array of the per-user contributions
  # making up that total.
  #
  class Cell < CalculatorWithUsers
    # No specialisations needed currently.
  end

  ###########################################################################
  # A Row stores an array of Cells accessed by a date-based key of
  # the caller's choosing (just be consistent in your choices). It
  # maintains its own running totals of the amounts in its cells,
  # complete with per-user totals for the contributions to the row.
  #
  class Row < CalculatorWithUsers

    def initialize
      super()

      task_actual_remaining = task_potential_remaining = BigDecimal.new( 0 )
      @cells = {}
    end

    # Return the Cell for the given date-based key, or 'nil' if
    # there is no such cell record for this row.
    #
    def cell( date_based_key )
      @cells[ date_based_key ]
    end

    # Return the Cell for the given date-based key, lazy-creating
    # a new instance if need be.
    #
    def cell!( date_based_key )
      @cells[ date_based_key ] ||= Cell.new
    end

    # Returns 'true' if there are any cells on this row, else 'false'.
    #
    def has_cells?
      not @cells.empty?
    end
  end

  ###########################################################################
  # A Section object keeps track of per-column totals within a set of
  # Rows, along with an overall section total.
  #
  # There may be many Rows that refer back to a given Section, the caller
  # being responsible for maintaining the mapping and count as they best
  # see fit.
  #
  # Section objects can maintain per-user contribution counts just as in
  # Rows, but callers may choose not to use that feature.
  #
  # In terms of API, a report's Section inherits from Row and incorporates
  # a TrackRecordSection module's Section behaviour too. This is basically
  # a direct subtitute, in this class's case, for multiple inheritance. We
  # want a report to expose a section/group interface and to support
  # calculation within section details at the same time.
  #
  class Section < Row

    include TrackRecordSections::SectionMixin # Note singular "Section"

    def initialize( identifier, project )
      super()
      initialize_section( identifier, project ) # TrackRecordSections::SectionMixin
    end
  end

  ###########################################################################
  # A Report object queries the database for a set of numbers and
  # compiles them into a set of Sections, Rows and Cells which can be
  # queried via a accessors and enumerators provided herein.
  #
  class Report < CalculatorWithUsers

    include TrackRecordSections::SectionsMixin # Note plural "Sections"

    # Configure the handlers and human-readable labels for the ways in
    # which reports get broken up, in terms of frequency. View code which
    # presents a choice of report frequency should obtain the labels for
    # the list with the 'label' method. Use the 'column_title' method for
    # a column "title", shown alongside or above column headings. Use the
    # 'column_heading' method for per-column headings.
    #
    # <em>These must stay in the same order!</em>
    #
    # If you add new entries, you must add them at the end of the list.
    #
    # Saved reports specify the reporting frequency by reference to this
    # constant and an index into its array of entries. If you produce a new
    # TrackRecord version that changes the meaning of any array index rather
    # than merely adding new entries, you will have to include a migration
    # that maps old indices to new for existing saved report records.
    #
    # == IMPORTANT! Database dependence
    #
    # <em>Executive summary: Reports are fast on PostgreSQL and slow on
    # anything else, unless you take steps to make sure they run quickly.</em>
    #
    # To run report sums in the database quickly, with minimum queries, the
    # database is asked to group its calculations. When we can group using
    # something that matches the columns of a report, we can get the
    # database to in effect calculate the entire body of the report in one
    # query. So for example, a monthly report would group by year and month
    # number; any given date produces a unique year and month.
    #
    # To do this, the SQL 'EXTRACT' function is used by default.
    #
    # * http://www.postgresql.org/docs/8.3/static/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT
    # * http://www.w3schools.com/sql/func_extract.asp
    # * http://docs.oracle.com/cd/B19306_01/server.102/b14200/functions050.htm
    #
    # With the standard report generator implementation, TrackRecord reports
    # rely on being able to extract:
    #
    # * YEAR (must match Ruby Date#year, i.e. numeric, four digit standard calendar year)
    # * QUARTER (must match Ruby Date#quarter, i.e. numeric 1-4, simple 3 full month splits)
    # * MONTH (must match Ruby Date#month, i.e. numeric 1-12)
    # * <em>WEEK - see below - so also ISOYEAR (PostgreSQL v8.3+ specific)</em>
    #   - Ruby mirrors ISOYEAR with Date#cwyear. PostgreSQL v8.3 and later also
    #   provide ISODOW (day-of-week), equivalent to Ruby's Date#cwday, but that
    #   is not needed by TrackRecord. 
    #
    # Weekly reports are thorny, because that requires grouping by some idea of
    # a unique numbered week. The commercial week number is the obvious choice.
    # MySQL and PostgreSQL provide a WEEK parameter for this in EXTRACT, but
    # <em>Oracle does not offer this and can't be used</em> without changing the
    # TrackRecord report generator's FREQUENCY constant for weekly reports, or
    # disabling weekly reports entirely.
    #
    # In any case, even that is insufficient. The 31st December 2012 marks the
    # start of commercial week number 1 for the commercial year 2013; but the
    # date itself is in calendar year 2012. January 1st 2006 is actually the
    # last day of commercial week 52 in the commercial year 2005, despite the
    # date being in calendar year 2006. If we were to just use a standard
    # calendar year, we'd get into trouble - 2012 would appear to contain week
    # 1 twice, leading to numbers from entirely different time periods being
    # combined in the report calculations.
    #
    # Thus <em><strong>weekly reports will only function if you use PostgreSQL
    # version 8.3 or later</strong></em> unless you modify the report code.
    # Without modifications, Oracle and MySQL should work (but are not tested).
    # Note that SQLite will <em><strong>not work at all</strong></em> as it has
    # no support for EXTRACT at all - you need to use 'strftime' instead, and
    # this provides easily enough flexibility to support weekly reports too:
    #
    # * http://www.sqlite.org/lang_datefunc.html
    # * http://stackoverflow.com/questions/9624601/activerecord-find-by-year-day-or-month-on-a-date-field
    #
    # To modify FREQUENCY for a different database:
    #
    # 1. Change "config/initializers/can_database_do_fast_reports.rb" so
    #    that the SLOW_DATABASE_ALTERNATIVE constant value is "false" for
    #    your database. Without this, you won't be able to test your
    #    modifications to FREQUENCY as a "safe mode" fallback is active.
    #
    # 2. Change the ":grouping" key to the equivalent of the EXTRACT already
    #    present, noting that it shoudld always be an array, even if there's
    #    only one group. Ensure that whatever you group by will lead to one
    #    group for every single unique column for the intended report,
    #    e.g. uniquely identifies months across many years, or weeks across
    #    awkward end-of-year boundaries.
    #
    # 3. Change the ":date_to_key" proc so that Ruby generates an array that
    #    matches the grouping keys returned by the database when it runs the
    #    query that calculates the report data. To find out that bit of the
    #    puzzle, search in "lib/track_record_report.rb" (i.e. this file) for
    #    the string "*date_based_key". You'll see a line of code that
    #    assigns this from a variable. Underneath that line, add in:
    #    "raise date_based_key.inspect" and generate a report of the column
    #    duration you are modifying, while in development mode. The raised
    #    exception will show in your browser the form of the value that the
    #    date-to-key proc must return.
    #
    # Also look at the code below the assignment of FREQUENCY to see how the
    # slow "safe mode" is done. You could always create those values inside
    # FREQUENCY by hand for report types you can't generate in the database.
    #
    FREQUENCY =
    [
      #total:
      {
        :label           => 'Totals only',
        :title           => '',
        :column          => :heading_total,
        :start_of_period => :all,
        :end_of_period   => :all
      },

      #tax_year:
      {
        :label           => 'UK tax year',
        :title           => 'UK tax year:',
        :column          => :heading_tax_year,
        :manual_columns  => true,
        :date_to_key     => ->( date ) { date },
        :start_of_period => :beginning_of_uk_tax_year,
        :end_of_period   => :end_of_uk_tax_year
      },

      #calendar_year:
      {
        :label           => 'Calendar year',
        :title           => 'Year:',
        :column          => :heading_calendar_year,
        :grouping        => [ 'EXTRACT(YEAR FROM date)' ],
        :date_to_key     => ->( date ) { [ date.year.to_s ] },
        :start_of_period => :beginning_of_year,
        :end_of_period   => :end_of_year
      },

      #calendar_quarter:
      {
        :label           => 'Calendar quarter',
        :title           => 'Quarter starting:',
        :column          => :heading_quarter,
        :grouping        => [ 'EXTRACT(YEAR FROM date)', 'EXTRACT(QUARTER FROM date)' ],
        :date_to_key     => ->( date ) { [ date.year.to_s, ( ( ( date.month - 1 ) / 3 ) + 1 ).to_s ] },
        :start_of_period => :beginning_of_quarter,
        :end_of_period   => :end_of_quarter
      },

      #calendar_month:
      {
        :label           => 'Monthly',
        :title           => 'Month:',
        :column          => :heading_month,
        :grouping        => [ 'EXTRACT(YEAR FROM date)', 'EXTRACT(MONTH FROM date)' ],
        :date_to_key     => ->( date ) { [ date.year.to_s, date.month.to_s ] },
        :start_of_period => :beginning_of_month,
        :end_of_period   => :end_of_month,
        :throttle        => :months
      },

      #calendar_week:
      {
        :label           => 'Weekly',
        :title           => 'Week starting:',
        :column          => :heading_weekly,
        :grouping        => [ 'EXTRACT(ISOYEAR FROM date)', 'EXTRACT(WEEK FROM date)' ],
        :date_to_key     => ->( date ) { [ date.cwyear.to_s, date.cweek.to_s ] },
        :start_of_period => :beginning_of_week,
        :end_of_period   => :end_of_week,
        :throttle        => :weeks
      },

      #day:
      {
        :label           => 'Daily',
        :title           => 'Date:',
        :column          => :heading_daily,
        :grouping        => [ '"work_packets"."date"' ],
        :date_to_key     => ->( date ) { [ date.strftime( '%Y-%m-%d' ) ] },
        :start_of_period => :beginning_of_day,
        :end_of_period   => :end_of_day,
        :throttle        => :days
      }
    ]

    if ( SLOW_DATABASE_ALTERATIVE ) # config/initializers/can_database_do_fast_reports.rb
      FREQUENCY.each do | frequency |
        if ( frequency[ :grouping ] )
          frequency.delete( :grouping )
          frequency[ :date_to_key ] = ->( date ) { date }
          frequency[ :manual_columns ] = true
        end
      end
    end

    # Optional report title.
    attr_accessor :title

    # Complete date range for the whole report; array of user IDs used for
    # per-user breakdowns; array of task IDs the report will represent.
    attr_accessor :range
    attr_reader   :reportable_user_ids, :task_ids, :active_task_ids, :inactive_task_ids # Bespoke "writer" methods are defined later

    # "Cacheable" range values. If a report's start or end date is fixed,
    # returns the date. If the start or end date are start/end-of-all-time,
    # one or both returns :all. If the report is being generated for a
    # relative month or week, returns "last_", "this_" or "two_" with a
    # suffix of "month" or "week", as a symbol, for both start and end.
    attr_reader :cacheable_start_indicator, :cacheable_end_indicator

    # A report's total date span may be restricted to avoid generating giant
    # reports which would swamp a server (for example, a daily report over
    # hundreds or thousands of days would be a bad idea). If not done, this
    # holds 'nil', else the Date giving the *original* start date (the
    # limited, actual start date used is in the "range" property).
    #
    # Views/generators can use it to include warnings that the start date was
    # limited, should they so wish.
    attr_reader :throttled

    # Range data for the 'new' view form. Custom attribute writer methods are
    # used to call "rationalise_dates" whenever a range value is altered.
    attr_reader :range_start, :range_end
    attr_reader :range_week_start, :range_week_end, :range_one_week
    attr_reader :range_month_start, :range_month_end, :range_one_month

    # Handle all ("all"), only billable ("billable") or only non-billable
    # ("non_billable") tasks?
    attr_accessor :task_filter

    # Sort fields for customers, projects and tasks; grouping options.
    attr_accessor :customer_sort_field, :project_sort_field, :task_sort_field
    attr_accessor :task_grouping

    # Show per-user detailed breakdowns for all tasks or just user summaries,
    # assuming any users are selected for such; inclusions and exclusions.
    [
      :user_details,
      :include_totals,
      :include_committed,
      :include_not_committed,
      :exclude_zero_rows,
      :exclude_zero_cols
    ].each do | sym |
      attr_reader sym
      self.instance_eval %(
        define_method( :#{ sym }= ) do | value |
          @#{ sym } = ( value == true || value == '1' || value == 'true' )
        end
      )
    end

    # A row from the FREQUENCY constant and the current index into that array.
    attr_reader :frequency_data, :frequency

    # Read-only array of actual user and task objects based on the IDs. Not all
    # users or tasks may be included, depending on security settings.
    attr_reader :users, :tasks    # Bespoke "reader" methods for active/inactive lists are defined later
    attr_accessor :filtered_tasks # Only valid after the "compile" method has been called.
    attr_accessor :filtered_users # Only valid after the "compile" method has been called.

    # Total duration of all tasks in all rows; number of hours remaining (may
    # be negative for overrun) after all hours worked in tasks with non-zero
    # duration. If 'nil', *all* tasks had zero duration. The 'actual' value
    # only accounts for committed hours, while the 'potential' value includes
    # both committed and not-committed hours (thus, subject to change).
    #
    # A report that hides zero total rows will not include task durations on
    # those rows. A report that shows them *will* include task durations on
    # those rows.
    attr_reader :total_duration, :total_actual_remaining, :total_potential_remaining

    # Create a new Report. In the first parameter, pass the current TrackRecord
    # user. In the next parameter pass nothing to use default values for a 'new
    # report' view form, or pass "params[ :report ]" (or similar) to create
    # using a params hash from a 'new report' form submission.
    #
    def initialize( current_user, params = nil )

      super()

      @current_user          = current_user

      @range_start           = nil
      @range_end             = nil
      @range_week_start      = nil
      @range_week_end        = nil
      @range_month_start     = nil
      @range_month_end       = nil
      @frequency             = 0

      @customer_sort_field   = 'title'
      @project_sort_field    = 'title'
      @task_sort_field       = Task::DEFAULT_SORT_COLUMN
      @task_grouping         = :default
      @task_filter           = 'all'

      @include_totals        = true
      @include_committed     = false
      @include_not_committed = false
      @exclude_zero_rows     = false
      @exclude_zero_cols     = false # Totals only - ignores zero com/non-com columns in CSV exports for total/com/non-com column groups with non-zero totals

      @rows                  = {}
      @column_totals         = {}
      @column_ranges         = []
      @column_keys           = []

      @tasks                 = Task.scoped
      @filtered_tasks        = Task.scoped
      @task_ids              = []
      @active_task_ids       = []
      @inactive_task_ids     = []

      @users                 = []
      @filtered_users        = []
      @reportable_user_ids   = []

      unless ( params.nil? )

        # Adapted from ActiveRecord::Base "attributes=", Rails 2.1.0
        # on 29-Jun-2008.

        attributes = params.dup
        attributes.stringify_keys!
        attributes.each do | key, value |
          if ( key.include?( '(' ) )
            raise( "Multi-parameter attributes are not supported." )
          else
            begin
              send( key + "=", value )
            rescue
              # Ignore errors
            end
          end
        end
      end
    end

    # Virtual accessor for the active task list, which just filters the master
    # task list and returns the result (less RAM than keeping dual lists and
    # not speed-critical as not used that often in practice).
    #
    def active_tasks
      @tasks.where( :active => true )
    end

    # As above, but for inactive tasks.
    #
    def inactive_tasks
      @tasks.where( :active => false )
    end

    # Set a task array directly (will always be filtered according to security
    # settings for the current user).
    #
    def tasks=( array )
      unless array.nil? || array.count.zero?
        @tasks = Task.where( :id => array )
      else
        @tasks = Task.scoped
      end

      update_internal_task_lists()
    end

    # Build the 'tasks' array if 'task_ids' is updated externally.
    #
    def task_ids=( ids )
      @provided_task_ids = map_raw_ids( ids )
      assign_actual_tasks_from_provided_ids()
    end

    # Build the 'tasks' array if 'active_task_ids' is updated externally. The
    # result will be the sum of existing inactive and updated active task IDs.
    #
    def active_task_ids=( ids )
      @provided_active_task_ids = map_raw_ids( ids )
      assign_actual_tasks_from_provided_ids()
    end

    # Build the 'tasks' array if 'inactive_task_ids' is updated externally. The
    # result will be the sum of existing active and updated inactive task IDs.
    #
    def inactive_task_ids=( ids )
      @provided_inactive_task_ids = map_raw_ids( ids )
      assign_actual_tasks_from_provided_ids()
    end

    # Build the 'user' array if 'reportable_user_ids' is updated externally.
    #
    def reportable_user_ids=( ids )
      ids ||= []
      ids = ids.values if ( ids.is_a?( Hash ) or ids.is_a?( HashWithIndifferentAccess ) )
      @reportable_user_ids = ids.map { | str | str.to_i }

      # Security - if the current user is restricted they might try and hack
      # the form to view other user details.

      if ( @current_user.restricted? )
        @reportable_user_ids = [ @current_user.id ] unless( @reportable_user_ids.empty? )
      end

      # Turn the list of (now numeric) user IDs into user objects.

      @users = User.where( :id => @reportable_user_ids )
    end

    # Set the 'frequency_data' field when 'frequency' is updated externally.
    #
    def frequency=( freq )
      @frequency      = freq.to_i
      @frequency_data = FREQUENCY[ @frequency ].dup
    end

    # Rationalise overall date ranges whenever a related field is updated
    # externally.

    def range_start=( value );       @range_start       = value; rationalise_dates(); end
    def range_end=( value );         @range_end         = value; rationalise_dates(); end
    def range_week_start=( value );  @range_week_start  = value; rationalise_dates(); end
    def range_week_end=( value );    @range_week_end    = value; rationalise_dates(); end
    def range_one_week=( value );    @range_one_week    = value; rationalise_dates(); end
    def range_month_start=( value ); @range_month_start = value; rationalise_dates(); end
    def range_month_end=( value );   @range_month_end   = value; rationalise_dates(); end
    def range_one_month=( value );   @range_one_month   = value; rationalise_dates(); end

    # Return the row defined for the given task ID, specified as a string.
    #
    # Will return 'nil' if no such row exists. Only really useful if the
    # report has been compiled by calling "compile".
    #
    def row( task_id_str )
      @rows[ task_id_str ]
    end

    # Return the row defined for the given task ID, specified as a string.
    #
    # Will create an empty Row instance in passing if necessary. Usually
    # only useful during the process of report compilation (see "compile")
    # but may have specialist external uses too.
    #
    def row!( task_id_str )
      @rows[ task_id_str ] ||= Row.new
    end

    # Return the total value as a Calculator subclass instance for the
    # column identified by the given date-based key.
    #
    # Will return 'nil' if no such non-zero total column exists (yet).
    # Only really useful if the report has been compiled by calling
    # "compile".
    #
    def column_total( date_based_key )
      @column_totals[ date_based_key ]
    end

    # Return the total value as a Cell instance for the column identified
    # by the given date-based key. A Cell class is used so that per-user
    # column totals can be maintained. Think of each column total as a
    # cell in an extra total-based row of the report.
    #
    # Will create an empty zero-hour Cell subclass instance in passing if
    # necessary. Usually only useful during the process of report
    # compilation (see "compile") but may have specialist external uses
    # too.
    #
    def column_total!( date_based_key )
      @column_totals[ date_based_key ] ||= Cell.new
    end

    # Only useful for compiled reports - see "compile".
    #
    # Returns 'true' if the report has any non-zero hours counted for any
    # of its rows, else 'false' (all tasks counted to zero hours within the
    # other report constraints/parameters).
    #
    def has_rows?
      not @rows.empty?
    end

    # Only useful for compiled reports - see "compile".
    #
    # Iterate over all defined rows, yielding a caller supplied block
    # passing it the row and task in task list order. If "hide zero rows"
    # is set, only defined rows and tasks with non-zero totals will be
    # sent. Otherwise, you will be called with a row value of 'nil' and
    # the task for which the row total was zero (it is much faster to
    # check for 'nil' many times than instantiate a useless row object
    # with zero values for its hours).
    #
    def each_row # :yields: row, task
      @filtered_tasks.each do | task |
        row = @rows[ task.id.to_s ]
        yield( row, task ) unless ( @exclude_zero_rows and row.nil? )
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Iterate over the cells in a given Row or Row subclass. Calls a
    # caller-supplied block, passing the cell instance. Will pass 'nil'
    # for cells with a zero hour total (it is much faster to check for
    # 'nil' many times than instantiate a useless cell object with zero
    # values for its hours).
    #
    # A 'nil' input parameter value is allowed. The caller block will
    # be invoked with 'nil' for each cell that *would* have been on the
    # row if it existed.
    #
    def each_cell_for( row ) # :yields: cell

      # We use zero column total values to indicate that an associated entry
      # in the column ranges should be omitted.

      if ( row.nil? )
        @relevant_column_keys.each { yield( nil ) }
      else
        @relevant_column_keys.each do | date_based_key |
          yield( row.cell( date_based_key ) )
        end
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Results of calling here are undefined unless the report parameters
    # tell it to include per-user details during compilation.
    #
    # For each user associated with a row, call the caller's block with the
    # User instance and the Calculator subclass giving the user's total on
    # that row. Will call with "nil" for each user in the row is "nil",
    # unless "hide zero rows" is enabled, in which case if given nil it will
    # not call the block at all.
    #
    # The block is only called for a non-nil row if a user has a non-zero
    # total, or if "hide zero rows" is disabled, in which case the user
    # total instance may be 'nil' (but the User is always valid).
    #
    # See also "each_cell_for_user_on_row".
    #
    def each_user_on_row( row ) # :yields: user, user_total_for_row

      # Not 'filtered_users' - those are aimed at the columns in reports
      # where each *column* represents a user, so hide-zero-columns will
      # result in hidden users. Here, we're looking at the per-user
      # breakdown for a single task on a row. If hide-zero-cols is set
      # but hide-zero-rows is not, we don't want to hide users here.

      if ( row.nil? )
        @users.each { | user | yield( user, nil ) } unless ( @exclude_zero_rows )
      else
        @users.each do | user |
          user_total_for_row = row.user_total( user.id.to_s )
          yield( user, user_total_for_row ) unless ( @exclude_zero_rows and user_total_for_row.nil? )
        end
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Results of calling here are undefined unless the report parameters
    # tell it to include per-user details during compilation.
    #
    # For a given user and row, return cells for that row giving the column
    # based totals for just that specific user. Zero columns are skipped if
    # "hide zero columns" is enabled.
    #
    # This is similar to just doing "each_cell_for( row )" and calling the
    # cell's "user_total" method manually for whatever your current User of
    # interest happens to be, but calling here takes care of that for you
    # and deals with 'nil' cleanly in passing.
    #
    # The given User instance must be valid. The given Row instance may be
    # 'nil'. If so, either the block is called with 'nil' for each column
    # if "hide zero rows" is disabled, else it isn't called at all.
    #
    def each_cell_for_user_on_row( user, row ) # :yields: cell_for_user
      if ( row.nil? )
        @relevant_column_keys.each { yield( nil ) } unless ( @exclude_zero_rows )
      else
        user_id_str = user.id.to_s

        @relevant_column_keys.each do | date_based_key |
          yield( row.cell( date_based_key ).try( :user_total, user_id_str ) )
        end
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Returns the number of columns the report generated, taking into account
    # zero total columns and the "hide zero columns" flag.
    #
    def column_count
      @relevant_column_keys.count
    end

    # Only useful for compiled reports - see "compile".
    #
    # Iterate over all column totals, calling the caller-supplied block
    # with a Calculator subclass describing the total for that column. If
    # the total is zero and 'hide zero columns' is disabled, your block
    # will be called with 'nil' for that column.
    #
    def each_column_total # :yields: column_total
      @relevant_column_keys.each do | date_based_key |
        yield( @column_totals[ date_based_key ] )
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Iterate over all columns, calling a caller-supplied block with a
    # Range object describing the Date range for each one, inclusive of
    # column start/end. Always calls with a valid Range, never 'nil'.
    #
    def each_column_range # :yields: column_range

      # We use zero column total values to indicate that an associated entry
      # in the column ranges should be omitted.

      @column_keys.each_with_index do | date_based_key, linear_column_index |
        next if ( @exclude_zero_cols and not @column_totals.has_key?( date_based_key ) )
        yield @column_ranges[ linear_column_index ]
      end
    end

    # Only useful for compiled reports - see "compile".
    #
    # Returns the number of users the report considered, taking into account
    # zero total users and the "hide zero columns" flag.
    #
    def user_count
      @filtered_users.count
    end

    # Only useful for compiled reports - see "compile".
    #
    # Iterate over the list of users passed in the constructor, calling a
    # caller-supplied block with the User instances in the order they were
    # originally given. If "hide zero columns" is set, then only users
    # with a non-zero overall total will be included.
    #
    def each_user # :yields: user
      @filtered_users.each { | user | yield( user ) }
    end

    # Compile the report. Returns 'self' for convenience.
    #
    def compile
      apply_filters()
      return if ( @filtered_tasks.count.zero? ) # Nothing to do...

      rationalise_dates()
      set_columns()
      sort_and_group()
      initialize_sections( @filtered_tasks, Section ) # TrackRecordSections::SectionsMixin

      calculate()

      self
    end

    # Helper method which returns a user-displayable label describing this
    # report type. There's a class method equivalent below.
    #
    def label
      return @frequency_data[ :label ]
    end

    # Helper method which returns a user-displayable range describing the
    # total date range for this report.
    #
    def display_range
      return heading_total( @range )
    end

    # Class method equivalent of "label" above. Returns the label for the
    # given frequency, which must be a valid index into the array defined
    # by the FREQUENCY constant. See also "labels" below.
    #
    def self.label( frequency )
      return Report::FREQUENCY[ frequency ][ :label ]
    end

    # Class method which returns an array of labels for various report
    # frequencies. The index into the array indicates the frequency index.
    #
    def self.labels
      return Report::FREQUENCY.map { | f | f[ :label ] }
    end

    # Helper method which returns a user-displayable column title to be shown
    # once, next to or near per-column headings (see "column_heading"),
    # appropriate for the report type.
    #
    def column_title
      return @frequency_data[ :title ]
    end

    # Helper method which returns a user-displayable column heading appropriate
    # for the report type. Pass a column range (see e.g. "each_column_range").
    # Optionally pass "true" to replace "<br />" with a space (if present) in
    # the heading, for a plain text alternative.
    #
    def column_heading( range, plain_text = false )
      heading = send( @frequency_data[ :column ], range )
      plain_text ? heading.gsub( "<br />", " " ) : heading
    end

    # Does the column at the given index only contain partial results, because
    # it is the first or last column in the overall range and that range starts
    # or ends somewhere in the middle? Returns 'true' if so, else 'false'.
    #
    def partial_column?( range )
      if ( range == @column_ranges.first )
        @column_first_partial
      elsif ( range == @column_ranges.last )
        @column_last_partial
      else
        false
      end
    end

  # =========================================================================

  private

  # =========================================================================

    # Internal helpers returning user-displayable column headings for various
    # different report types. Pass the date range to display and, for some of
    # the methods, optional format strings for date formatting.
    #
    # These methods are referred to by the ':column' keys in 'FREQUENCY'.

    def heading_total( range, format = '%d-%b-%Y' ) # DD-Mth-YYYY
      "#{ heading_start( range, format ) } to #{ heading_end( range, format ) }"
    end

    def heading_start( range, format = '%d-%b-%Y' ) # DD-Mth-YYYY
      "#{ range.min.strftime( format ) }"
    end

    def heading_end( range, format = '%d-%b-%Y' ) # DD-Mth-YYYY
      "#{ range.max.strftime( format ) }"
    end

    def heading_tax_year( range )
      year = range.min.beginning_of_uk_tax_year.year
      return "#{ year } / #{ year + 1 }"
    end

    def heading_calendar_year( range )
      return range.min.year.to_s
    end

    def heading_month( range, format = '%b %Y' ) # Mth-YYYY
      return range.min.strftime( format )
    end

    def heading_quarter( range )
      date    = range.min
      quarter = ( ( date.month - 1 ) / 3 ) + 1
      return "Q#{ quarter } #{ date.year }"
    end

    def heading_weekly( range, format = '%d-%b-%Y' ) # DD-Mth-YYYY
      return "#{ range.min.strftime( '%d %b' ) }<br />#{ range.min.year }: #{ range.min.cweek }".html_safe()
    end

    def heading_daily( range, format = '%d-%b-%Y' ) # DD-Mth-YYYY
      return range.min.strftime( format )
    end

    # Map raw ID values, supplied as an array or hash values and individually
    # as strings or integers, to an array of integers, returning the result.
    # Handles YUI tree submissions by always splitting and re-combining the
    # array contents based on ",".
    #
    def map_raw_ids( ids )
      ids ||= []
      ids = ids.values if ( ids.class == Hash or ids.class == HashWithIndifferentAccess )
      ids.map { | str | str.to_i }
    end

    # Build the internal @task_ids, @active_task_ids and @inactive_task_ids
    # lists based on the caller-provided master list of IDs, active IDs or
    # inactive IDs. Basically we can't trust that the caller has an up to date
    # view of what is active or what a current user can see, so we always take
    # the union of the caller's values and build our own internal view of it.
    #
    def assign_actual_tasks_from_provided_ids()
      @task_ids = ( ( @provided_task_ids || [] ) + ( @provided_active_task_ids || [] ) + ( @provided_inactive_task_ids || [] ) ).uniq
      @tasks    = Task.where( :id => @task_ids )

      update_internal_task_lists()
    end

    # Back-end to "assign_tasks_from_ids" and for direct task list assignments.
    #
    def update_internal_task_lists

      @tasks = @tasks.all # Collapse relation to a real query.

      # Security - discard tasks the user should not be able to see.

      if ( @current_user.restricted? )
        @tasks.select do | task |
          task.is_permitted_for?( @current_user )
        end
      end

      # Now the fiddly bit! Sort the task objects by augmented title, then
      # retrospectively rebuild the task ID arrays using the reordered list.

      Task.sort_by_augmented_title( @tasks )

      @task_ids          = []
      @active_task_ids   = []
      @inactive_task_ids = []

      @tasks.each do | task |
        @task_ids          << task.id
        @active_task_ids   << task.id if     ( task.active )
        @inactive_task_ids << task.id unless ( task.active )
      end

      # Convert back to an association for further conditional use later.

      @tasks = Task.where( :id => @task_ids )
    end

    # Unpack a string of the form "number_number[_number...]" and return the
    # numbers as an array of integers (e.g. "12_2008" becomes [12, 2008]).
    #
    def unpack_string( rstr )
      return rstr.split( '_' ).collect() { | str | str.to_i() }
    end

    # Return the current month, 1 month ago or two months ago as an array
    # with year and month number. Pass what you want to use as 'now' as a
    # DateTime instance, then "last" for last month, "two" for two
    # months ago, else returns this month (and year).
    #
    def relative_month_to( now, distanceAsAWord )
      date = case distanceAsAWord
        when "last"
          now - 1.month
        when "two"
          now - 2.months
        else
          now
      end

      [ date.year, date.month ]
    end

    # As "relative_month_to" but returns commercial week numbers.
    #
    def relative_week_to( now, distanceAsAWord )
      date = case distanceAsAWord
        when "last"
          now - 1.week
        when "two"
          now - 2.weeks
        else
          now
      end

      [ date.year, date.cweek ]
    end

    # Apply task selection filters to @tasks thus initialising @filtered_tasks.
    #
    def apply_filters
      @filtered_tasks = ( @tasks.count.zero? ) ? @current_user.all_permitted_tasks : @tasks.dup

      case @task_filter
        when 'billable'
          conditions = { :billable => true }

        when 'non_billable'
          conditions = { :billable => false }
      end

      @filtered_tasks = @filtered_tasks.where( conditions )
    end

    # Apply sorting and grouping to the filtered tasks list. Method
    # "apply_filters" must have been called first.
    #
    def sort_and_group
      @customer_sort_field = validate_sort_field( @customer_sort_field )
      @project_sort_field  = validate_sort_field( @project_sort_field  )
      @task_sort_field     = validate_sort_field( @task_sort_field     )

      # So always sort by customer, then project; then collect by the
      # active/billable groups if requested; then finally sort by the
      # requested task sort field. This must come last else it overrides
      # the active/billable grouping specification (e.g. we'd ask the
      # database to sort by task name, *then* by billable/active - too
      # late - we want a grouping effect, sorting by those flags first).

      @filtered_tasks = @filtered_tasks.reorder( "\"customers\".\"#{ @customer_sort_field }\" ASC" ).
                                          order( "\"projects\".\"#{ @project_sort_field }\" ASC" )

      if ( @task_grouping == 'billable' || @task_grouping == 'both' )
        @filtered_tasks = @filtered_tasks.order( '"tasks"."billable" ASC' )
      end

      if ( @task_grouping == 'active' || @task_grouping == 'both' )
        @filtered_tasks = @filtered_tasks.order( '"tasks"."active" ASC' )
      end

      @filtered_tasks = @filtered_tasks.order( "\"tasks\".\"#{ @task_sort_field }\" ASC" )
    end

    # Make sure a sort field variable is valid (users may try to hack in other
    # bits of SQL or field names). Pass a sort field value. Returns the same
    # value or 'title' if the value was invalid.
    #
    def validate_sort_field( value )
      if [ 'title', 'code', 'created_at' ].include?( value )
        return value
      else
        return 'title'
      end
    end

    # Call to return -1, 0 or 1 as part of sorting an array of tasks. Pass two
    # tasks to compare and an options hash.
    #
    #   Key                       Value
    #   =======================================================================
    #   :group_by_billable     If 'true', sort/group tasks by the billable
    #                          flag, else ignore this while sorting.
    #
    #   :group_by_active       If 'true', sort/group tasks by the active flag,
    #                          else ignore this while sorting.
    #
    #   :customer_sort_field   Field (method name) to use for comparing the
    #                          customers of tasks, or :title if omitted.
    #
    #   :project_sort_field    Field (method name) to use for comparing the
    #                          projects of tasks, or :title if omitted.
    #
    #   :task_sort_field       Field (method name) to use for comparing tasks
    #                          directly (because all other properties are
    #                          equal), or :title if omitted.
    #
    def complex_sort( task_a, task_b, options )

      # Implement grouping by billable and/or active flags by using these as
      # sort parameters. The order of the checks means that if grouping by both
      # flags we'll get a sort order of billable/active, billable/inactive,
      # non-billable/active, non-billable/inactive.

      if ( options[ :group_by_billable ] )
        return -1 if ( task_a.billable && ! task_b.billable )
        return  1 if ( task_b.billable && ! task_a.billable )
      end

      if ( options[ :group_by_active ] )
        return -1 if ( task_a.active && ! task_b.active )
        return  1 if ( task_b.active && ! task_a.active )
      end

      # More conventional sorting - we group by customer, then by project, then
      # finally sort by the task itself. The field used for the sorting of each
      # of the three object types is configurable and usually one of :title,
      # :code or :created_at.
      #
      # Liberal use of 'try' to deal with unassigned items - tasks with no
      # project, projects with no customer. Any "<=>" comparison with 'nil' will
      # result in 'nil' and a failed sort, so return '0' for such cases to treat
      # any nil comparison as 'same' (the "|| 0" at the end of comparison lines).

      if ( task_a.project.try( :customer_id ) != task_b.project.try( :customer_id ) )
        method = options[ :customer_sort_field ] || :title
        return ( task_a.project.try( :customer ).try( method ) <=> task_b.project.try( :customer ).try( method ) ) || 0
      elsif ( task_a.project_id != task_b.project_id )
        method = options[ :project_sort_field ] || :title
        return ( task_a.project.try( method ) <=> task_b.project.try( method ) ) || 0
      else
        method = options[ :task_sort_field ] || :title
        return ( task_a.send( method ) <=> task_b.send( method ) ) || 0
      end
    end

    # Turn the start and end times into a Date range; if there are
    # any errors, use defaults instead.
    #
    def rationalise_dates
      default_range              = date_range()
      @cacheable_start_indicator = nil
      @cacheable_end_indicator   = nil

      # The "range_one_..." entries are unusual, storing a string that
      # indicates a date relative to 'this instant in time' - "last"
      # for a last week/month/etc., "two" for two weeks/months/etc. ago,
      # else default to the current week/month/etc. instead.
      #
      # Order of precedence: Relative month; specific month; relative
      # week; specific week; exact date; fall back to all-time.
      #
      # We take a shapshot of "now" before doing any range calculations
      # using it to avoid any chance of the clock rolling over to a new
      # date mid-way through (that'd be incredibly unlucky, but it is
      # still technically possible if we re-read the clock each time).

      now = DateTime.now.utc

      begin
        if ( not @range_one_month.blank? )
          year, month = relative_month_to( now, @range_one_month )
          range_start = Date.new( year, month )
          @cacheable_start_indicator = "#{ @range_one_month }_month".to_sym

        elsif ( not @range_month_start.blank? )
          year, month = unpack_string( @range_month_start )
          range_start = Date.new( year, month )

        elsif ( not @range_one_week.blank? )
          year, week = relative_week_to( now, @range_one_week )
          range_start = Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY, true )
          @cacheable_start_indicator = "#{ @range_one_week }_week".to_sym

        elsif ( not @range_week_start.blank? )
          year, week = unpack_string( @range_week_start )
          range_start = Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY, true )

        else
          range_start = Date.parse( @range_start.to_s ) # Forces an exception if range_start is nil, to fall back to all-time; else harmlessly re-parses date.

        end

      rescue
        range_start = default_range.min
        @cacheable_start_indicator = :all

      end

      begin
        if ( not @range_one_month.blank? )
          year, month = relative_month_to( now, @range_one_month )
          range_end = Date.new( year, month ).at_end_of_month()
          @cacheable_end_indicator = "#{ @range_one_month }_month".to_sym

        elsif ( not @range_month_end.blank? )
          year, month = unpack_string( @range_month_end )
          range_end = Date.new( year, month ).at_end_of_month()

        elsif ( not @range_one_week.blank? )
          year, week = relative_week_to( now, @range_one_week )
          range_end = Timesheet.date_for( year, week, TimesheetRow::LAST_DAY, true )
          @cacheable_end_indicator = "#{ @range_one_week }_week".to_sym

        elsif ( not @range_week_end.blank? )
          year, week = unpack_string( @range_week_end )
          range_end = Timesheet.date_for( year, week, TimesheetRow::LAST_DAY, true )

        else
          range_end = Date.parse( @range_end.to_s ) # Forces an exception if range_start is nil, to fall back to all-time; else harmlessly re-parses date.

        end

      rescue
        range_end = default_range.max
        @cacheable_end_indicator = :all

      end

      if ( range_end < range_start )
        @range = range_end..range_start
      else
        @range = range_start..range_end
      end

      @cacheable_start_indicator ||= @range.first
      @cacheable_end_indicator   ||= @range.last

      # Does this report type throttle its date range?

      throttle        = nil
      throttle_method = @frequency_data[ :throttle ]

      if ( throttle_method )
        throttle_value  = REPORT_MAX_COLUMNS # config/initializers/general_config.rb
        throttle_value /= 2 if ( @user_details ) # Twice the columns as there are two reports, so half the limit in each

        throttle = throttle_value.send( throttle_method )
      end

      if ( throttle && @range.last.to_time - @range.first.to_time > throttle )
        @throttled = @range.first
        @range     = ( @range.last - throttle )..( @range.last )
      end
    end

    # Based on the current value of "@range", calculate the column
    # ranges and date-based keys into columns recovered from a raw
    # database query that extracts grouped report data.
    #
    # Usually, "rationalise_dates" is called before calling here.
    #
    def set_columns

      # Create an array containing every column's date range
      # given the report's overall range and it's column
      # duration (AKA frequency). For speed, for each start
      # date in each range, cache a set of the hash index keys
      # used to retrieve e.g. cells in rows; these must match
      # the equivalent data retrieved from the database in the
      # raw grouped query. The report's frequency-based
      # generator data provides the information needed to do
      # all of this.

      start_of_period_method = @frequency_data[ :start_of_period ]
      end_of_period_method   = @frequency_data[ :end_of_period   ]
      date_to_key_proc       = @frequency_data[ :date_to_key     ]
      period_start_day       = range.min # (implicitly inclusive)
      report_end_day         = range.max # (".max" not ".last" => inclusive)

      if ( end_of_period_method == :all )

        # Since there are no subgroups for an "all" total report,
        # the date-based key arising from the raw database results
        # ends up as an empty array; so simply set that here, so
        # we can index the single full-range column of results
        # using that same key.

        @column_ranges.push( range )
        @column_keys.push( [] )
        @column_first_partial = @column_last_partial = false

      else

        # First work out the "is a partial column?" flags.

        first_column_quantised_start = period_start_day.send( start_of_period_method ).to_date
        last_column_quantised_end    = report_end_day.send( end_of_period_method ).to_date

        @column_first_partial = ( first_column_quantised_start < period_start_day )
        @column_last_partial  = ( last_column_quantised_end    > report_end_day   )

        # Then work out the individual column ranges while respecting the true
        # report date range for the first and last columns.

        begin

          column_end_day = period_start_day.send( end_of_period_method ).to_date
          period_end_day = [ column_end_day, report_end_day ].min

          @column_ranges.push( period_start_day..period_end_day )
            @column_keys.push( date_to_key_proc.call( period_start_day ) )

          period_start_day = period_end_day + 1

        end while ( period_start_day <= report_end_day )

        # Sanity check in case anyone modifies the column key procs for a new
        # database, or I make changes and screw them up :-)

        if ( @column_keys.count != @column_keys.uniq.count )
          message = "\nInside lib/track_record_report.rb:\nColumn keys are not unique - check the documentation for the FREQUENCY constant and make sure the date-to-key procs are operating properly\n"
          Rails.logger.fatal( message )
          raise( message )
        end
      end
    end

    # Return the default Date range for a report - from the 1st January
    # on the first year that Timesheet.allowed_range() reports as valid, to
    # "today", if no work packets exist; else the date of the earliest and
    # latest work packets over all selected tasks (@task_ids array must be
    # populated with permitted task IDs, or "nil" for 'all tasks').
    #
    def date_range
      earliest = WorkPacket.find_earliest_by_tasks( @task_ids )
      latest   = WorkPacket.find_latest_by_tasks( @task_ids )

      # If the earliest or latest work packet value is nil, both should be
      # nil (obviously) and this means there are no work packets for the
      # tasks. In that case we just span 'all of time' so that the user
      # can see explicitly there's no booked time. Generating a report over
      # some single day range just looks odd (user thinks "why hasn't it
      # covered all dates"). The hide-zero-columns option can be employed
      # to clear up the report.

      end_of_range   = latest.nil?   ? Date.current                                    : latest.date
      start_of_range = earliest.nil? ? Date.new( Timesheet.allowed_range().min, 1, 1 ) : earliest.date

      return ( start_of_range..end_of_range )
    end

    # With all other pre-compilation steps completed, such as date
    # rationalisation, task sorting and grouping and so-on, call here
    # to calculate the report's numerical data.
    #
    def calculate

      # First run the numbers - simple for report types that can be
      # column-width-grouped by the database, tricky for things such as
      # "UK tax year".

      if ( @frequency_data[ :manual_columns ] )
        @column_ranges.each_with_index do | range |
          run_sums_for_range( range, range.min )
        end
      else
        run_sums_for_range( @range )
      end

      # Now set up a few things based on the result of report calculation.
      #
      # If zero-total rows are being omitted, the Section engine will end
      # up reporting incorrect values for start-of-group/section, should
      # that start-of-<x> task lie in a row that has a zero total and will
      # thus be omitted. We must take steps to fix that. It's easy enough
      # since rows only exist at this point if their total is non-zero
      # anyway, so we just iterate over existing rows to get the non-zero
      # task list.
      #
      # We can use the same loop to work out the task statistics while we
      # are here - the total task duration, the remaining time based on
      # committed hours and the potential remaining based on not committed
      # hours as well.

      non_zero_tasks             = []
      @total_duration            = BigDecimal.new( 0 );
      @total_actual_remaining    = BigDecimal.new( 0 );
      @total_potential_remaining = BigDecimal.new( 0 );

      each_row do | row, task |
        non_zero_tasks << task

        @total_duration += task.duration

        unless task.duration.zero?
          task_actual_remaining    = task.duration - ( row.try( :committed ) || 0 )
          task_potential_remaining = task.duration - ( row.try( :total     ) || 0 )

          @total_actual_remaining    += task_actual_remaining
          @total_potential_remaining += task_potential_remaining
        end
      end

      if ( @exclude_zero_rows )
        reassess_start_flags_using( non_zero_tasks ) # TrackRecordSections::SectionsMixin
      end

      # Cache the non-zero column date based keys to speed up column
      # iterators. If hiding zero columns, only columns defined in the
      # 'column_totals' hash should be used, so iterate via its set of
      # keys; else iterate over all available column keys.
      #
      # Can't just use e.g. "@column_keys.keys.sort" to try and get at an
      # ordered set of non-zero column keys, as the keys don't sort quite
      # how we expect (e.g. ["2013","30"] comes before ["2013","4"], with
      # effects similarly variable for all the different, unpredictable
      # column keys that FREQUENCY can produce).

      @relevant_column_keys = if @exclude_zero_cols
        @column_keys.select do | key |
          @column_totals.has_key?( key )
        end
      else
        @column_keys
      end

      # A similar thing happens for zero columns in user-based reports.
      # The "@user_totals" hash comes in via the inheritance from the
      # CalculatorWithUsers class.

      if ( @exclude_zero_cols )
        @filtered_users = User.where( :id => @user_totals.keys ) unless @users.count.zero?
      else
        @filtered_users = @users.dup
      end

      # Finally, collapse all internal relations to the actual lists of
      # objects. Downstream report clients are many and varied and will
      # iterate over this data in all sorts of ways; benchmarking shows
      # that leaving these as relations in perpetuity results in
      # significantly worse performance (e.g. one example heavy test
      # case reduced request time from around 1600ms to 1350ms).

               @tasks =          @tasks.try( :all ) if (          @tasks.is_a? ActiveRecord::Relation )
               @users =          @users.try( :all ) if (          @users.is_a? ActiveRecord::Relation )
      @filtered_tasks = @filtered_tasks.try( :all ) if ( @filtered_tasks.is_a? ActiveRecord::Relation )
      @filtered_users = @filtered_users.try( :all ) if ( @filtered_users.is_a? ActiveRecord::Relation )
    end

    # Back-end to "calculate". Runs the calculation engine using all th
    # normal database constraints, over a given range.
    #
    def run_sums_for_range( range, override_key = nil )

      joins  = { :timesheet_row => [ :task, { :timesheet => :user } ] }
      groups = [
        '"tasks"."id"',
        '"users"."id"',
        '"timesheets"."committed"'
      ]

      non_zero             = [ 'worked_hours > ?', BigDecimal.new( 0 ) ]
      conditions           = { :date => range }
      conditions[ :tasks ] = { :id   => @filtered_tasks.map( &:id ) } unless @filtered_tasks.count.zero?
      conditions[ :users ] = { :id   =>          @users.map( &:id ) } unless          @users.count.zero?

      grouping = @frequency_data[ :grouping ]
      groups  += grouping unless ( grouping.nil? )

      # This does all the database leg work, pulling in summed work packets
      # for all of the assembled conditions, grouped into a hash keyed by
      # data that depends upon 'groups', with BigDecimal sum result values.

      assoc = WorkPacket.joins( joins ).where( conditions ).where( non_zero ).order( groups )
      sums  = assoc.sum( :worked_hours, :group => groups )

      # The raw data needs to be assembled into a useful report.
      #
      # It may seem like a lot of effort counting up all the sums from the
      # database, especially for the per-user totals. However, we must avoid
      # hitting the database multiple times - each call executes quickly at
      # the "other end" but RPC calls are extremely slow compared to local
      # arithmetic, even in Ruby on BigDecimal objects.
      #
      # Simply assigning a BigDecimal value is about ten times faster than
      # adding one. So we might consider doing two database sums - one split
      # by user ID, one not; at least that would eliminate the per-cell user
      # additions. However, over a test sample of around 50,000 objects, the
      # in-Ruby overhead down in Rails for taking the database response and
      # building the big hash of results is pretty huge - this in fact takes
      # up the lion's share of the time spent herein. It easily eclipsed any
      # savings made from subsequent assign-instead-of-add in benchmark
      # tests during development.
      #
      # Thus this simple approach is surprisingly good - one single big
      # database call, a large hash of slow built but fast-to-process raw
      # data and a counted, totalled, object orientated representation
      # constructed quickly from there.
      #
      # Incidentally best-guess memory analysis on a 64-bit platform seems
      # to indicate a < 256K stored RAM requirement for the raw data object
      # in Ruby using the 50,000 work packet data set. So even for really
      # very large reports by TrackRecord standards (imagine a 50,000 cell
      # HTML table!) the RAM overhead of even our more structured OOP
      # representation is surprisingly small.

      sums.each do | key, value |

        # Key is array of task ID, user ID, "t"/"f" indication of
        # committed/not-committed all as strings, then group-dependent
        # extra data that uniquely identifies the date-related column.
        #
        # Unpack the array into more easily understood variables. Note
        # how "date" collects the remaining values in "key" and will
        # be an array even if it only ends up with one array entry.

        if ( override_key )
          task_id_str, user_id_str, flag_str = key
          date_based_key = override_key
        else
          task_id_str, user_id_str, flag_str, *date_based_key = key
        end

        # Some databases return grouped data with integer IDs (e.g.
        # sqlite) and Rails doesn't do anything about it; make sure
        # IDs are coerced to strings (we don't coerce to numbers as
        # some databases might not use purely numeric IDs).

        task_id_str = task_id_str.to_s
        user_id_str = user_id_str.to_s

        # The current row's overall total and its per-user breakdown.
        # In a standard task report, this would appear on the right of
        # each row.

        current_row             = row!( task_id_str )
        user_row_total          = current_row.user_total!( user_id_str )

        # The cell within the current row and its per-user breakdown.
        # In a standard task report, these appear as the report body.

        current_cell            = current_row.cell!( date_based_key )
        user_cell_total         = current_cell.user_total!( user_id_str )

        # The total for the column the cell lies in and that column's
        # per-user breakdown. In a standard task report, these appear
        # along the bottom for each of the date based columns.

        column_total            = column_total!( date_based_key )
        user_column_total       = column_total.user_total!( user_id_str )

        # Overall report per-user total (part of 'self'). In a standard
        # task report, this appears in the bottom right corner. The
        # overall cross-user total, also in the bottom right, is
        # calculated below directly via 'self'/'@[not_]committed'.

        user_overall_total      = user_total!( user_id_str )

        # The total for all rows within the current section and the
        # section's per-user breakdown for all of those rows. In a
        # standard task report, this appears on the right of the
        # section's header row.

        row_section             = section( task_id_str ) # TrackRecordSections::SectionsMixin
        user_section_total      = row_section.user_total!( user_id_str )

        # The total for each column over the rows within the current
        # section and each column's per-user breakdown. In a standard
        # task report, these appear along the section header row, for
        # each of the date based columns.

        section_cell            = row_section.cell!( date_based_key )
        user_section_cell_total = section_cell.user_total!( user_id_str )

        if ( flag_str === 't' )
                  user_cell_total.committed      = value
                     current_cell.committed     += value
                   user_row_total.committed     += value
                      current_row.committed     += value
                user_column_total.committed     += value
                     column_total.committed     += value

               user_overall_total.committed     += value # Per-user part of "self"
                                 @committed     += value # The "self" overall total

          user_section_cell_total.committed     += value
                     section_cell.committed     += value
               user_section_total.committed     += value
                      row_section.committed     += value
        else
                  user_cell_total.not_committed  = value
                     current_cell.not_committed += value
                   user_row_total.not_committed += value
                      current_row.not_committed += value
                     column_total.not_committed += value
                user_column_total.not_committed += value

                                 @not_committed += value
               user_overall_total.not_committed += value

                      row_section.not_committed += value
               user_section_total.not_committed += value
                     section_cell.not_committed += value
          user_section_cell_total.not_committed += value
        end
      end
    end

  end # 'class Report < CalculatorWithUsers'
end   # 'module TrackRecordReport'
