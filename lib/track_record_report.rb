########################################################################
# File::    track_record_report.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Mixin providing classes which represent all aspects of a
#           TrackRecord report.
# ----------------------------------------------------------------------
#           29-Jun-2008 (ADH): Created.
########################################################################

module TrackRecordReport

  # Very simple base class used to store some common properties and
  # methods for objects which deal with worked hours.
  #
  class ReportElementaryCalculator

    # Committed, not committed hours (floats)
    attr_accessor :committed, :not_committed

    def initialize
      reset!()
    end

    # Returns total worked hours (committed plus not committed).
    #
    def total
      return ( @committed + @not_committed )
    end

    # Returns 'true' if the object records > 0 total hours, else 'false'.
    #
    def has_hours?
      return ( total() > 0.0 )
    end

    # Add the given calculator's committed and not committed hours to this
    # calculator's hours.
    #
    def add!( calculator )
      @committed     += calculator.committed
      @not_committed += calculator.not_committed
    end

    # Opposite of 'add!'.
    #
    def subtract!( calculator )
      @committed     -= calculator.committed
      @not_committed -= calculator.not_committed
    end

    # Reset the object's hour counts.
    #
    def reset!
      @committed     = 0.0
      @not_committed = 0.0
    end
  end

  #############################################################################
  # CALCULATION SUPPORT - MAIN REPORT OBJECT
  #############################################################################

  # Class which manages a report.
  #
  class Report < ReportElementaryCalculator

    include TrackRecordSections

    # Configure the handlers and human-readable labels for the ways in
    # which reports get broken up, in terms of frequency. View code which
    # presents a choice of report frequency should obtain the labels for
    # the list with the 'label' method. Use the 'column_title' method for
    # a column "title", shown alongside or above column headings. Use the
    # 'column_heading' method for per-column headings.

    FREQUENCY = [
      { :label => 'Totals only',      :title => '',                  :column => :heading_total,             :generator => :totals_report                                          },
      { :label => 'UK tax year',      :title => 'UK tax year:',      :column => :heading_tax_year,          :generator => :periodic_report, :generator_arg => :end_of_uk_tax_year },
      { :label => 'Calendar year',    :title => 'Year:',             :column => :heading_calendar_year,     :generator => :periodic_report, :generator_arg => :end_of_year        },
      { :label => 'Calendar quarter', :title => 'Quarter starting:', :column => :heading_quarter_and_month, :generator => :periodic_report, :generator_arg => :end_of_quarter     },
      { :label => 'Monthly',          :title => 'Month:',            :column => :heading_quarter_and_month, :generator => :periodic_report, :generator_arg => :end_of_month       },
      { :label => 'Weekly',           :title => 'Week starting:',    :column => :heading_weekly,            :generator => :periodic_report, :generator_arg => :end_of_week        },

      # Daily reports are harmful since they can cause EXTREMELY large reports
      # to be generated and this can take longer than the web browser will wait
      # before timing out. In the mean time, Rails keeps building the report...
      #
      # Previously daily reports were disabled to work around this. Now, a hard
      # coded date throttle stops the generation of daily reports for more than
      # a 60 day period before the end date.

      { :label => 'Daily',            :title => 'Date:',             :column => :heading_daily,             :generator => :daily_report                                           },
    ]

    # Complete date range for the whole report; array of user IDs used for
    # per-user breakdowns; array of task IDs the report will represent.
    attr_accessor :range
    attr_reader   :user_ids, :task_ids, :active_task_ids, :inactive_task_ids # Bespoke "writer" methods are defined later

    # Range data for the 'new' view form.
    attr_accessor :range_start, :range_end
    attr_accessor :range_week_start, :range_week_end
    attr_accessor :range_month_start, :range_month_end

    # Handle all ("all"), only billable ("billable") or only non-billable
    # ("non_billable") tasks?
    attr_accessor :task_filter

    # Sort fields for customers, projects and tasks; grouping options.
    attr_accessor :customer_sort_field, :project_sort_field, :task_sort_field
    attr_accessor :task_grouping

    # Inclusions and exclusions.
    [
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

    # A row from the FREQUENCY constant and the current index into that array,
    # as a stringify_keys.
    attr_reader :frequency_data, :frequency

    # Read-only array of actual user and task objects based on the IDs; call
    # "build_task_and_user_arrays" to build it. Not all users or tasks may be
    # included, depending on security settings.
    attr_reader :users, :tasks    # Bespoke "reader" methods for active/inactive lists are defined later
    attr_accessor :filtered_tasks # Only valid after the "compile" method has been called.
    attr_accessor :filtered_users # Only valid after the "compile" method has been called.

    # Array of ReportRows making up the report. The row objects contain
    # arrays of cells, corresponding to columns of the report.
    attr_reader :rows

    # Array of ReportSection objects describing per-section totals of various
    # kinds. See the ReportSection class and TrackRecordSections module for
    # details.
    attr_reader :sections

    # Number of columns after all calculations are complete; this is the same
    # as the size of the 'column_ranges' or 'column_totals' arrays below, but
    # using this explicit property is likely to make code more legible.
    attr_reader :column_count

    # Array of ranges, one per column, giving the range for each of
    # the columns held within the rows. The indices into this array match
    # indices into the rows' cell arrays.
    attr_reader :column_ranges

    # Array of ReportColumnTotal objects, one per column, giving the total
    # hours for that column. The indices into this array match indices into
    # the rows' cell arrays.
    attr_reader :column_totals

    # Total duration of all tasks in all rows; number of hours remaining (may
    # be negative for overrun) after all hours worked in tasks with non-zero
    # duration. If 'nil', *all* tasks had zero duration. The 'actual' value
    # only accounts for committed hours, while the 'potential' value includes
    # both committed and not-committed hours (thus, subject to change).
    attr_reader :total_duration, :total_actual_remaining, :total_potential_remaining

    # Array of ReportUserColumnTotal objects, each index corresponding to a
    # user the "users" array at the same index. These give the total work done
    # by that user across all rows.
    attr_reader :user_column_totals

    # Create a new Report. In the first parameter, pass the current TrackRecord
    # user. In the next parameter pass nothing to use default values for a 'new
    # report' view form, or pass "params[ :report ]" (or similar) to create
    # using a params hash from a 'new report' form submission.
    #
    def initialize( current_user, params = nil )
      @current_user = current_user

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

      @tasks                 = []
      @filtered_tasks        = []
      @task_ids              = []
      @active_task_ids       = []
      @inactive_task_ids     = []

      @users                 = []
      @filtered_users        = []
      @user_ids              = []

      unless ( params.nil? )

        # Adapted from ActiveRecord::Base "attributes=", Rails 2.1.0
        # on 29-Jun-2008.

        attributes = params.dup
        attributes.stringify_keys!
        attributes.each do | key, value |
          if ( key.include?( '(' ) )
            raise( "Multi-parameter attributes are not supported." )
          else
            send( key + "=", value )
          end
        end
      end
    end

    # Virtual accessor for the active task list, which just filters the master
    # task list and returns the result (less RAM than keeping dual lists and
    # not speed-critical as not used that often in practice).
    #
    def active_tasks
      @tasks.select { | task | task.active }
    end

    # As above, but for inactive tasks.
    #
    def inactive_tasks
      @tasks.select { | task | ! task.active }
    end

    # Set a task array directly (will always be filtered according to security
    # settings for the current user).
    #
    def tasks=( array )
      @tasks = array
      update_internal_task_lists()
    end

    # Build the 'tasks' array if 'task_ids' is updated externally.
    #
    def task_ids=( ids )
      @task_ids = map_raw_ids( ids )
      assign_tasks_from_ids( @task_ids )
    end

    # Build the 'tasks' array if 'active_task_ids' is updated externally. The
    # result will be the sum of existing inactive and updated active task IDs.
    #
    def active_task_ids=( ids )
      @active_task_ids = map_raw_ids( ids )
      assign_tasks_from_ids( @active_task_ids, @inactive_task_ids )
    end

    # Build the 'tasks' array if 'inactive_task_ids' is updated externally. The
    # result will be the sum of existing active and updated inactive task IDs.
    #
    def inactive_task_ids=( ids )
      @inactive_task_ids = map_raw_ids( ids )
      assign_tasks_from_ids( @active_task_ids, @inactive_task_ids )
    end

    # Build the 'user' array if 'user_ids' is updated externally.
    #
    def user_ids=( ids )
      ids ||= []
      ids = ids.values if ( ids.is_a?( Hash ) or ids.is_a?( HashWithIndifferentAccess ) )
      @user_ids = ids.map { | str | str.to_i }

      # Security - if the current user is restricted they might try and hack
      # the form to view other user details.

      if ( @current_user.restricted? )
        @user_ids = [ @current_user.id ] unless( @user_ids.empty? )
      end

      # Turn the list of (now numeric) user IDs into user objects.

      @users = User.active.find( @user_ids )
    end

    # Set the 'frequency_data' field when 'frequency' is updated externally.
    #
    def frequency=( freq )
      @frequency      = freq.to_i
      @frequency_data = FREQUENCY[ @frequency ]
    end

    # Compile the report.
    #
    def compile
      rationalise_dates()
      apply_filters()
      sort_and_group()

      return if ( @filtered_tasks.empty? )

      add_rows()
      add_columns()
      calculate!()
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
    # given frequency, which must be a valid index into Report::FREQUENCY.
    # See also "labels" below.
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
    # for the report type. Pass the column index.
    #
    def column_heading( col_index )
      col_range = @column_ranges[ col_index ]
      return send( @frequency_data[ :column ], col_range )
    end

    # Does the column at the given index only contain partial results, because
    # it is the first or last column in the overall range and that range starts
    # or ends somewhere in the middle? Returns 'true' if so, else 'false'.
    #
    def partial_column?( col_index )

# [TODO] Doesn't work, because col_range accurately reflects the column range
#        rather than the quantised range. Getting at the latter is tricky, so
#        leaving this for later. At present the method is only used for display
#        purposes in the column headings.

      col_range = @column_ranges[ col_index ]
      return ( col_range.first < @range.first or col_range.last > @range.last )
    end

  private

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

    # Given an array of numerical IDs, assign "@tasks" to the (permitted) array
    # of corresponding tasks, sorted by augmented title. Pass an optional extra
    # array of IDs which is added to the first. "@task_ids" is set to the sum
    # of the two arrays. You can thus directly set @task_ids by just passing in
    # one array with the IDs you want; or combine e.g. active and inactive
    # task lists by passing those two arrays instead.
    #
    # Note that @task_ids, @active_task_ids and @inactive_task_ids will all be
    # reconstructed at the end of the method so that they contain an updated,
    # sorted ID list taking account of current user task viewing permissions.
    #
    def assign_tasks_from_ids( id_array_1, id_array_2 = [] )
      @task_ids = id_array_1 + id_array_2
      @tasks    = Task.find( @task_ids )

      update_internal_task_lists()
    end

    # Back-end to "assign_tasks_from_ids" and for direct task list assignments.
    #
    def update_internal_task_lists

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
    end

    # Unpack a string of the form "number_number[_number...]" and return the
    # numbers as an array of integers (e.g. "12_2008" becomes [12, 2008]).
    #
    def unpack_string( rstr )
      return rstr.split( '_' ).collect() { | str | str.to_i() }
    end

    # Apply task selection filters to @tasks thus initialising @filtered_tasks.
    #
    def apply_filters
      @filtered_tasks = ( @tasks.empty? ) ? @current_user.active_permitted_tasks : @tasks.dup

      case @task_filter
        when 'billable'
          @filtered_tasks.reject! { | task | ! task.billable }

        when 'non_billable'
          @filtered_tasks.reject! { | task |   task.billable }
      end
    end

    # Apply sorting and grouping to the filtered tasks list. Method
    # "apply_filters" must have been called first.
    #
    def sort_and_group
      @customer_sort_field = validate_sort_field( @customer_sort_field )
      @project_sort_field  = validate_sort_field( @project_sort_field  )
      @task_sort_field     = validate_sort_field( @task_sort_field     )

      @filtered_tasks.sort! do | task_a, task_b |
        complex_sort(
          task_a,
          task_b,
          {
            :group_by_billable   => ( @task_grouping == 'billable' || @task_grouping == 'both' ),
            :group_by_active     => ( @task_grouping == 'active'   || @task_grouping == 'both' ),
            :customer_sort_field => @customer_sort_field,
            :project_sort_field  => @project_sort_field,
            :task_sort_field     => @task_sort_field
          }
        )
      end
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
      # sort paramneters. The order of the checks means that if grouping by both
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

      if ( task_a.project.customer_id != task_b.project.customer_id )
        method = options[ :customer_sort_field ] || :title
        return task_a.project.customer.send( method ) <=> task_b.project.customer.send( method )
      elsif ( task_a.project_id != task_b.project_id )
        method = options[ :project_sort_field ] || :title
        return task_a.project.send( method ) <=> task_b.project.send( method )
      else
        method = options[ :task_sort_field ] || :title
        return task_a.send( method ) <=> task_b.send( method )
      end
    end

    # Turn the start and end times into a Date range; if there are
    # any errors, use defaults instead.
    #
    def rationalise_dates
      default_range = date_range()

      begin
        if ( not @range_month_start.blank? )
          year, month = unpack_string( @range_month_start )
          range_start = Date.new( year, month )
        elsif ( not @range_week_start.blank? )
          year, week = unpack_string( @range_week_start )
          range_start = Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY, true )
        else
          range_start = Date.parse( @range_start )
        end
      rescue
        range_start = default_range.first
      end

      begin
        if ( not @range_month_end.blank? )
          year, month = unpack_string( @range_month_end )
          range_end = Date.new( year, month ).at_end_of_month()
        elsif ( not @range_week_end.blank? )
          year, week = unpack_string( @range_week_end )
          range_end = Timesheet.date_for( year, week, TimesheetRow::LAST_DAY, true )
        else
          range_end = Date.parse( @range_end )
        end
      rescue
        range_end = default_range.last
      end

      if ( range_end < range_start )
        @range = range_end..range_start
      else
        @range = range_start..range_end
      end

      # Hard-coded range throttle to 32 days (just over a "longest month") for
      # daily reports to avoid excessive server load.

      if ( @frequency_data[ :generator ] == :daily_report )
        @range = ( @range.last - 32.days )..( @range.last ) if ( @range.last.to_time - @range.first.to_time > 32.days )
      end
    end

    # Return the default date range for a report - from the 1st January
    # on the first year that Timesheet.allowed_range() reports as valid, to
    # "today", if no work packets exist; else the date of the earliest and
    # latest work packets over all selected tasks (@task_ids array must be
    # populated with permitted task IDs, or "nil" for 'all tasks').
    #
    def date_range
      earliest = WorkPacket.find_earliest_by_tasks( @task_ids )
      latest   = WorkPacket.find_latest_by_tasks( @task_ids )

      end_of_range   = latest.nil?   ? Date.current                                      : latest.date.to_date
      start_of_range = earliest.nil? ? Date.new( Timesheet.allowed_range().first, 1, 1 ) : earliest.date.to_date

      return ( start_of_range..end_of_range )
    end

    # Create row objects for the report as a first stage of report compilation.
    #
    def add_rows
      @rows = []
      @filtered_tasks.each do | task |
        row = ReportRow.new( task )
        @rows.push( row )
      end
    end

    # Once all rows are added with add_rows, they need populating with columns.
    # Call here to do this. The Report's user information, task information
    # etc. will all be used to populate the rows with cells describing the
    # worked hours condition for that row and column.
    #
    # Each cell added onto a row's array of cells has its date range stored at
    # the same index in the @column_ranges array and a ReportColumnTotal object
    # stored at the same index in the @column_totals array.
    #
    def add_columns
      @column_ranges = []
      @column_totals = []

      # Earlier versions of the report generator asked the database for very
      # specific groups of work packets for date ranges across individual
      # columns. Separate queries were made for per-user breakdowns. This got
      # very, very slow far too easily. There's a big RAM penalty for reading
      # in all work packets in one go, but doing this and iterating over the
      # required items on each column within Ruby is much faster overall.

      @committed_work_packets     = []
      @not_committed_work_packets = []
      user_ids                    = @user_ids.empty? ? nil : @user_ids

      @filtered_tasks.each_index do | index |
        task_id = @filtered_tasks[ index ]

        @committed_work_packets[ index ] = WorkPacket.find_committed_by_task_user_and_range(
            @range,
            task_id,
            user_ids
        )

        @not_committed_work_packets[ index ] = WorkPacket.find_not_committed_by_task_user_and_range(
            @range,
            task_id,
            user_ids
        )
      end

      # Generate the report by calling the generator in the FREQUENCY constant.
      # Generators iterate over the report's date range, calling add_column
      # (note singular name) for each iteration.

      send( @frequency_data[ :generator ], @frequency_data[ :generator_arg ] )

      # Finish off by filling in the column count property.

      @column_count = @column_totals.size()
    end

    # Add columns to the report, with each column spanning one day of the total
    # report date range.
    #
    def daily_report( report, ignored = nil )
      @range.each do | day |
        add_column( day..day )
      end
    end

    # Add columns to the report, with each column spanning one period the total
    # report date range. The period is determined by the second parameter. This
    # must be a method name that, when invoked on a Date object, returns the end
    # of a period given a date within that period. For example, method names
    # ":end_of_week" or ":end_of_quarter" would result in one column per week or
    # one column per quarter, respectively.
    #
    # If the report's total date range starts or ends part way through a column,
    # then that column will contain only data from the report range. That is, the
    # range is *not* quantised to a column boundary.
    #
    def periodic_report( end_of_period_method )
      period_start_day = @range.first
      report_end_day   = @range.last

      begin
        column_end_day = period_start_day.send( end_of_period_method )
        period_end_day = [ column_end_day, report_end_day ].min

        add_column( period_start_day..period_end_day )
        period_start_day = period_end_day + 1
      end while ( @range.include?( period_start_day ) )
    end

    # Add a single column to the given report spanning the total report date
    # range.
    #
    def totals_report( ignored = nil )
      add_column( @range )
    end

    # Add a column containing data for the given range of Date objects.
    #
    def add_column( range )
      col_total = ReportColumnTotal.new

      @filtered_tasks.each_index do | task_index |
        task      = @filtered_tasks[ task_index ]
        row       = @rows[ task_index ]
        cell_data = ReportCell.new

        # Work out the total for this cell, which will take care of per-user
        # totals in passing.

        committed     =
        not_committed =

        cell_data.calculate!(
          range,
          @committed_work_packets[ task_index ],
          @not_committed_work_packets[ task_index ],
          @user_ids
        )

        # Include the cell in this row and the running column total.

        row.add_cell( cell_data )
        col_total.add_cell( cell_data )
      end

      @column_ranges.push( range )
      @column_totals.push( col_total )
    end

    # Compute row, column and overall totals for the report. You must have
    # run 'add_columns' beforehand.
    #
    def calculate!

      # Set up variables used by the remove zero rows/columns feature.

      if ( @include_totals || ( @include_committed && @include_non_committed ))
        zero_check_method = :total
      elsif ( @include_committed )
        zero_check_method = :committed
      else
        zero_check_method = :not_committed
      end

      # Remove zero total rows if asked to do so.

      if ( @exclude_zero_rows )
        row_removals = []

        @rows.each_index do | index |
          row = @rows[ index ]
          row_removals << index if ( row.send( zero_check_method ).zero? )
        end

        row_removals.reverse.each do | index |
          @rows.delete_at( index )
          @filtered_tasks.delete_at( index )
        end
      end

      # Remove zero total columns if asked to do so.

      if ( @exclude_zero_cols )

        # Compile a list of column indices for removal, then delete elements
        # in arrays corresponding to this column but running backwards through
        # the list so that lower numbered indices remain valid as we delete
        # entries in higher numbered indices.

        column_removals = []

        @column_totals.each_index do | index |
          column_removals << index if ( @column_totals[ index ].send( zero_check_method ).zero? )
        end

        column_removals.reverse.each do | index |
          @rows.each do | row |
            row.delete_cell( index )
          end
          @column_ranges.delete_at( index )
          @column_totals.delete_at( index )
        end
      end

      # Calculate total task duration.

      @total_duration = 0.0

      @filtered_tasks.each do | task |
        @total_duration += task.duration
      end

      # Reset the task summary totals.

      @total_actual_remaining = @total_potential_remaining = nil

      # Calculate the grand total across all rows.

      reset!()

      @rows.each_index do | row_index |
        row  = @rows[ row_index ]
        task = @filtered_tasks[ row_index ]

        add!( row )

        if ( task.duration > 0 )
          @total_actual_remaining    ||= @total_duration
          @total_potential_remaining ||= @total_duration

          @total_actual_remaining    -= row.committed
          @total_potential_remaining -= row.total
        end
      end

      # Work out the row totals for individual users.

      @users.each_index do | user_index |
        @rows.each do | row |
          user_row_total = ReportUserRowTotal.new
          user_row_total.calculate!( row, user_index )
          row.add_user_row_total( user_row_total )
        end
      end

      # Use that to generate the overall user totals.

      @user_column_totals = []

      @users.each_index do | user_index |
        user_column_total = ReportUserColumnTotal.new
        user_column_total.calculate!( @rows, user_index )
        @user_column_totals[ user_index ] = user_column_total
      end

      # Remove zero total columns if asked to do so.

      if ( @exclude_zero_cols )
        @filtered_users = []
        column_removals = []

        @users.each_index do | user_index |
          if ( @user_column_totals[ user_index ].send( zero_check_method ).zero? )
            column_removals << user_index
          else
            @filtered_users << @users[ user_index ]
          end
        end

        column_removals.reverse.each do | index |
          @rows.each do | row |
            row.delete_user_row_total( index )
          end
          @user_column_totals.delete_at( index )
        end

      else
        @filtered_users = @users.dup

      end

      # Now move on to section calculations.

      sections_initialise_sections()

      @sections       = []
      current_section = nil

      @rows.each_index do | row_index |
        row  = @rows[ row_index ]
        task = @filtered_tasks[ row_index ]

        if ( sections_new_section?( task ) )
          current_section = ReportSection.new
          @sections.push( current_section )
        end

        raise( "Section calculation failure in report module" ) if ( current_section.nil? )

        row.cells.each_index do | cell_index |
          cell = row.cells[ cell_index ]
          current_section.add_cell( cell, cell_index )
        end

        row.user_row_totals.each_index do | user_index |
          user_row_total = row.user_row_totals[ user_index ]
          current_section.add_user_row_total( user_row_total, user_index )
        end
      end

    end

    # Helper methods which return a user-displayable column heading for various
    # different report types. Pass the date range to displayl

    def heading_total( range )
      format = '%d-%b-%Y' # DD-Mth-YYYY
      return "#{ range.first.strftime( format ) } to #{ range.last.strftime( format ) }"
    end

    def heading_tax_year( range )
      year = range.first.beginning_of_uk_tax_year.year
      return "#{ year } / #{ year + 1 }"
    end

    def heading_calendar_year( range )
      return range.first.year.to_s
    end

    def heading_quarter_and_month( range )
      return range.first.strftime( '%b %Y' ) # Mth-YYYY
    end

    def heading_weekly( range )
      return "#{ range.first.strftime( '%d-%b-%Y' ) } (#{ range.first.cweek })" # DD-Mth-YYYY
    end

    def heading_daily( range )
      return range.first.strftime( '%d-%b-%Y' ) # DD-Mth-YYYY
    end
  end

  #############################################################################
  # CALCULATION SUPPORT - OBJECTS FOR ROWS, CELLS, TOTALS
  #############################################################################

  # Store information about a specific task over a full report date range.
  # The parent report contains information about that range.
  #
  class ReportRow < ReportElementaryCalculator
    # Array of ReportCell objects
    attr_reader :cells

    # Array of ReportUserRowTotal objects
    attr_reader :user_row_totals

    # Task for which this row exists
    attr_reader :task

    def initialize( task )
      super()
      @cells           = []
      @user_row_totals = []
      @task            = task
    end

    # Add the given ReportCell object to the "@cells" array and increment
    # the internal running total for the row.
    #
    def add_cell( cell )
      @cells.push( cell )
      add!( cell )
    end

    # Delete a ReportCell object from the "@cells" array at the given index.
    #
    def delete_cell( index )
      subtract!( @cells[ index ] )
      @cells.delete_at( index )
    end

    # Call to add ReportUserRowTotal objects to the row's @user_row_totals
    # array.
    #
    def add_user_row_total( user_row_total )
      @user_row_totals.push( user_row_total )
    end

    # Call to delete a row total from a specific index.
    #
    def delete_user_row_total( index )
      @user_row_totals.delete_at( index )
    end
  end

  # Rows are grouped into sections. Whenever the customer or project of the
  # currently processed row differs from a previously processed row, a new
  # section is declared. The report's "sections" array should be accessed by
  # section index (see module TrackRecordSections for details).
  #
  # Section objects contain an array of ReportCell objects, just like a row,
  # only this time each cell records the total hours in the column spanning
  # all rows within the section. There is also a "user_row_totals" array, again
  # recording the hours for the user across the whole report time range and
  # across all rows in the section.
  #
  # The ReportSection object's own hour totals give the sum of all hours by
  # anybody across the whole report time range and all rows in the section.
  # This is analogous to a ReportRow object's totals.
  #
  # Section totals are best calculated after the main per-row and per-column
  # report data has been worked out for all rows and columns.
  #
  class ReportSection < ReportElementaryCalculator
    # Array of ReportCell objects. Analogous to the same-name array in a
    # ReportRow, but each cell corresponds to all rows in this section.
    attr_reader :cells

    # Array of ReportUserRowTotal objects. Again, analogous to the same-name
    # array in a ReportRow, but correspond to multiple rows.
    attr_reader :user_row_totals

    def initialize
      super()
      @cells           = []
      @user_row_totals = []
    end

    # Add the given ReportCell to the "@cells" array at the given cell index.
    # If there is already a cell at this index, then add the hours to that
    # cell. This makes it easy to iterate over rows and their cells, then add
    # those hours progressively to the section cells to produce the multiple-
    # row section totals.
    #
    def add_cell( cell, cell_index )
      dup_or_calc( @cells, cell, cell_index )
      add!( cell )
    end

    # Call to add ReportUserRowTotal objects to the row's @user_row_totals
    # array at the given user index. Again, multiple calls for the same index
    # cause hours to be added, as with "add_cell" above.s
    #
    def add_user_row_total( user_row_total, user_index )
      dup_or_calc( @user_row_totals, user_row_total, user_index )
    end

  private

    # To the given array, add a duplicate of the given object at the given
    # index should the array not contain anything at that index, else add
    # the hours from the object to whatever is already in the array.

    def dup_or_calc( array, object, index )
      array[ index ] = object.class.new if ( array[ index ].nil? )
      array[ index ].add!( object )
    end
  end

  # Store information about a specific task over a column's date range.
  #
  # The object does not store the task or range data since this would be
  # redundant across potentially numerous instances leading to significant
  # RAM wastage. Instead:
  #
  # - The ReportCell objects are stored in a ReportRow "cells" array. The
  #   array indices correspond directly to array indices of the Report's
  #   "ranges" array, compiled as the first row of the report gets built.
  #
  # - The ReportRows' "task" property gives the task object for that row.
  #
  # So - to find task and range, you need to know the row index of the
  # ReportRow and the column index of the ReportCell this contains.
  #
  class ReportCell < ReportElementaryCalculator
    # User breakdown for this cell
    attr_reader :user_data

    def initialize()
      super()
      @user_data = []
    end

    # Add the given ReportUserData object to the "@user_data" array and
    # add it to the internal running hourly count.
    #
    def add_user_data( data )
      @user_data.push( data )
      add!( data )
    end

    # Pass a date range, an array of committed work packets sorted by date
    # descending, an array of not committed work packets sorted by date
    # descending and an optional user IDs array. Hours are summed for work
    # packets across the given range. Any work packets falling within the range
    # are removed from the arrays. Separate totals for each of the users in the
    # given array are maintained in the @user_data array.
    #
    def calculate!( range, committed, not_committed, user_ids = [] )
      # Reset internal calculations and pre-allocate ReportUserData objects for
      # each user (if any).

      reset!()
      @user_data = []

      user_ids.each_index do | user_index |
        @user_data[ user_index ]= ReportUserData.new
      end

      # Start and the end of the committed packets array. For anything within
      # the given range, add the hours to the internal total and add to the
      # relevant user

      @committed = sum(
        range,
        committed,
        user_ids,
        :add_committed_hours
      )

      # Same again, but for not committed hours.

      @not_committed = sum(
        range,
        not_committed,
        user_ids,
        :add_not_committed_hours
      )
    end

  private

    # For the given array of work packets sorted by date descending, check the
    # last entry and see if it is in the given range. If it is, include its
    # worked hours in a running total and pop the item off the array. Pass an
    # array of user IDs also and a method to call on an entry in the @user_data
    # array; if the work packet's associated user ID is in the array then the
    # user data object at the corresponding index in @user_data will have the
    # given method called and passed the packet.
    #
    def sum( range, packets, user_ids, user_data_method )
      total  = 0.0
      packet = packets[ -1 ]

      while ( ( not packets.empty? ) and ( range.include?( packet.date.to_date ) ) )
        total += packet.worked_hours

        index = user_ids.index( packet.timesheet_row.timesheet.user_id )
        @user_data[ index ].send( user_data_method, packet ) unless ( index.nil? )

        packets.pop()
        packet = packets[ -1 ]
      end

      return total
    end
  end

  # Object used to handle running column totals. The Report object creates
  # one each time it adds a column. For each cell that is calculated, call
  # the ReportColumnTotal's "add_cell" method to increment the running
  # total for the column.
  #
  class ReportColumnTotal < ReportElementaryCalculator

    # See above.
    #
    def add_cell( cell_data )
      add!( cell_data )
    end
  end

  # Store information about a user's worked hours for a specific cell - that
  # is, a specific task and date range. ReportUserData objects are associated
  # with ReportCells, and those cells deal with passing over hours to be
  # included in the user data total.
  #
  class ReportUserData < ReportElementaryCalculator

    # Add the given work packet's hours to the internal committed total.
    #
    def add_committed_hours( packet )
      @committed += packet.worked_hours
    end

    # Add the given work packet's hours to the internal not committed total.
    #
    def add_not_committed_hours( packet )
      @not_committed += packet.worked_hours
    end
  end

  # Analogous to ReportUserData, but records the a user's total worked hours
  # for the whole row. ReportUserRowTotal objects should be added to a UserRow
  # in the order the users appear in the Report's @users array so that indices
  # match between user data arrays in cells and the row user total arrays.
  #
  class ReportUserRowTotal < ReportElementaryCalculator

    # Pass a ReportRow object containing user data to count and the index
    # in the cell user data arrays of the user in which you have an
    # interest.
    #
    def calculate!( row, user_index )
      reset!()

      row.cells.each do | cell |
        user_data = cell.user_data[ user_index ]
        add!( user_data )
      end
    end
  end

  # Analogous to ReportUserRowTotal, but sums across all rows. The objects
  # should be added to the Report object @user_column_totals array in the order
  # of appearance in the Report's @users array.
  #
  class ReportUserColumnTotal < ReportElementaryCalculator

    # Pass an array of ReportRow objects to sum over and the index
    # in the row user summary arrays of the user in which you have an
    # interest.
    #
    def calculate!( rows, user_index )
      reset!()

      rows.each do | row |
        add!( row.user_row_totals[ user_index ] )
      end
    end
  end
end
