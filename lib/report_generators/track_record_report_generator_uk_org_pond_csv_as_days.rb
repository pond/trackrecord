########################################################################
# File::    track_record_report_generator_uk_org_pond_csv_as_days.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Generate CSV format reports and send the data to browsers.
#           Hours are rounded to half or full days. Weekend hours are
#           redistributed. UK Bank Holiday hours are redistributed.
# ----------------------------------------------------------------------
#           25-Jul-2013 (ADH): Created.
########################################################################

module TrackRecordReportGenerator::UkOrgPondCSVAsDays

  require 'csv'

  DAY_LENGTH             = BigDecimal.new( "7.5" )
  DUMMY_HOURS_DAY_LENGTH = BigDecimal.new( "8.0" )

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def understands?( type )
    case type
      when :comprehensive, :task
        true
      else
        false
    end
  end

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def invocation_button_title_for( type )
    case type
      when :comprehensive, :task
        "Export rounded-day based report in CSV format"
    end
  end

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def invocation_options_for( type )
    [
      {
        :radio =>
        {
          :label   => 'Calculate days on a per-month basis',
          :checked => true,
          :name    => "cm_#{ type }",
          :id      => uk_org_pond_month_rounding_id_for_type( type )
        },
      },
      {
        :radio =>
        {
          :label   => 'Calculate days across entire report date span',
          :checked => false,
          :name    => "cm_#{ type }",
          :id      => uk_org_pond_range_rounding_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'If working per-month, carry rounding errors to the next month?',
          :checked => false,
          :id      => uk_org_pond_carry_rounding_id_for_type( type )
        },
      },
      { :gap => true },
      {
        :checkbox =>
        {
          :label   => 'Redistribute hours away from weekends? (Daily reports only)',
          :checked => true,
          :id      => uk_org_pond_redistribute_weekends_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Redistribute hours away from bank holidays? (Daily reports only)',
          :checked => true,
          :id      => uk_org_pond_redistribute_bank_holidays_id_for_type( type )
        },
      },
      { :gap => true },
      {
        :checkbox =>
        {
          :label   => 'Add title to first row',
          :checked => true,
          :id      => uk_org_pond_include_title_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Include date column',
          :checked => true,
          :id      => uk_org_pond_include_dates_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Include dummy "start time"/"end time" columns',
          :checked => true,
          :id      => uk_org_pond_include_times_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Include day-rounded hours column',
          :checked => true,
          :id      => uk_org_pond_include_rounded_hours_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Include dummy weekend rows',
          :checked => true,
          :id      => uk_org_pond_include_weekend_rows_id_for_type( type )
        },
      },
      {
        :checkbox =>
        {
          :label   => 'Include bank holiday names',
          :checked => false,
          :id      => uk_org_pond_include_bank_holiday_names_id_for_type( type )
        },
      }
    ]
  end

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def generate( report_type, report, params = {} )
    options = {}
    names   = [
      :carry_rounding,

      :redistribute_weekends,
      :redistribute_bank_holidays,

      :include_title,
      :include_dates,
      :include_times,
      :include_rounded_hours,
      :include_weekend_rows,
      :include_bank_holiday_names
    ]

    names.each do | name |
      method = "uk_org_pond_#{ name }_id_for_type"
      value  = ( params[ send( method, report_type ) ] == '1' )

      options[ name ] = value
    end

    options[ :calculate_monthly ] = ( params[ "calculate_monthly_#{ report_type }" ] == uk_org_pond_month_rounding_id_for_type( report_type ) )

    # Processing takes place either report-wide, or over monthly columns.
    # Work out our local processing columns for workday calculations.

    if ( options[ :calculate_monthly ] )
      column_ranges = []
      month_start   = report.range.min.beginning_of_month
      report_start  = report.range.min
      report_end    = report.range.max

      # Note we record "accurate" ranges, not spanning beyond the overall
      # report date range.

      begin
        dmin = [ month_start,              report_start ].min
        dmax = [ month_start.end_of_month, report_end   ].max
        column_ranges << [ dmin..dmax ]
        month_start += 1.month
      end while ( month_start < report_end )

    else
      column_ranges = [ report.range ]

    end

    # TODO: Column ranges are ignored.
    # TODO: Column rounding options are ignored.
    # TODO: We always calculate daily over the whole report time range.

    # First thing's first. Do we need to redistribute hours away from any
    # weekends and/or bank holidays? If so, figure out which days are to
    # be avoided and how many are left.

    reportable_day_count = report.range.count
    avoided_days         = {}
    nowe                 = options[ :redistribute_weekends      ]
    nobh                 = options[ :redistribute_bank_holidays ]
    frequency_data       = TrackRecordReport::Report::FREQUENCY[ report.frequency ]
    is_daily             = ( frequency_data[ :end_of_period ] == :end_of_day )

    # Always load this; it might be needed later.

    bhmap = YAML.load_file( File.join( Rails.root,
                                       'lib',
                                       'report_generators',
                                       'track_record_report_generator_uk_org_pond_csv_as_days',
                                       'uk_bank_holidays.yml' ) )

    if ( is_daily )
      if ( nowe || nobh )
        report.range.each do | day |
          if ( ( nowe && day.cwday > 5 ) || ( nobh && bhmap.has_key?( day ) ) )
            avoided_days[ day ] = true
          end
        end

        reportable_day_count -= avoided_days.count

        if ( reportable_day_count < 0 )
          message = "\nInside lib/report_generators/track_record_report_generator_uk_org_pond_csv_as_days.rb:\nLess than zero reportable days\n"
          Rails.logger.fatal( message )
          raise( message )
        end
      end
    end

    # Compile a simple easily sortable array of hours vs dates ready
    # for workday allocations, in passing redistributing hours away
    # from weekends/bank holidays if need be.
    #
    # In a daily report, we are considering per user, per day, per task
    # hours. These equate to a single work packet in a timesheet and,
    # since a timesheet is either committed or not, the hours we are
    # looking at here are either committed or not, never both.
    #
    # For attempts to run equivalent workdays over multiple day periods
    # for wider columns (weekly, monthly etc.), trying to figure out the
    # quantisation of workdays against both committed and not committed
    # hours simultaneously, making sure we never exceeed a total of "1
    # workday multiplied by column width in days" for committed and not
    # committed hours for that user in that column is *way* too complex
    # and simply not needed under the at-time-of-writing loose spec for
    # this generator.
    #
    # Thus we collapse everything down to totals internally and make no
    # distinction between committed or not committed hours, but we DO
    # take note if there's a mixture and generate a warning in the
    # output so the reader knows the result contains both combined.

    has_committed      = false # I.e. does the report have any committed hours?
    has_not_committed  = false # I.e. does the report have any not committed hours?
    big_zero           = BigDecimal.new( 0 )

    users              = {}
    redistribute_hours = ( is_daily && ! avoided_days.count.zero? && ! reportable_day_count.zero? )
    date_to_key_proc   = frequency_data[ :date_to_key ]

    reportable_day_count > 0 && report.each_row do | row, task |
      next if ( row.nil? )

      report.each_user_on_row( row ) do | user, user_total_for_row |
        next if ( user_total_for_row.nil? || user_total_for_row.total().zero? )

        non_zero_col_count = 0
        task_id_str        = task.id.to_s
        user_id_str        = user.id.to_s
        user_data          = users     [ user  ] ||= {}
        row_data           = user_data [ task  ] ||= {}
        days_data          = row_data  [ :days ]   = {}
        hours_array        = []

        # If redistributing hours, we assume the report type is daily
        # (see definition of "redistribute_hours" above).

        if ( redistribute_hours )

          # Count how many hours in this row are to be redistributed.
          # May as well lazy-create user total cells as we do this, as
          # we'll need them later for the redistribution anyway.

          hours_to_redistribute = big_zero

          report.range.each do | date |

            date_based_key  = date_to_key_proc.call( date )
            cell            = row.cell!( date_based_key )
            user_total_cell = cell.user_total!( user_id_str )
            total           = user_total_cell.total()

            has_committed     = true unless ( user_total_cell.committed.zero? )
            has_not_committed = true unless ( user_total_cell.not_committed.zero? )

            hours_to_redistribute += total if ( avoided_days.has_key?( date ) )

          end

          # Get per-day adjustments to the existing committed and not
          # committed totals for this user on this row based on the
          # actual number of hours-allowed-on-it days.

          adjustments = uk_org_pond_redistribution_amounts_for(
            hours_to_redistribute,
            reportable_day_count
          )

          # IMPORTANT: AFTER THIS STEP, CELL OVERALL VALUES WILL BE
          # WRONG AND COLUMN TOTALS WILL BE WRONG. SECTIONS ARE IGNORED.
          # ALL HOURS ARE COLLAPSED INTO THE "COMMITTED" VALUE AND THE
          # NOT-COMMITTED FIGURES ARE ERASED.

          report.range.each do | date |

            date_based_key  = date_to_key_proc.call( date )
            cell            = row.cell!( date_based_key )
            user_total_cell = cell.user_total!( user_id_str )

            if ( avoided_days.has_key?( date ) )
              user_total_cell.committed = big_zero
            else
              user_total_cell.committed = user_total_cell.total() + adjustments.pop()
            end

            user_total_cell.not_committed = big_zero

            hours_array.push( [ user_total_cell.committed, date ] )
            non_zero_col_count += 1 unless ( user_total_cell.committed.zero? )
          end

        else # 'if ( redistribute_hours )'

          # Even if not redistributing hours, still have to build up an array
          # of committed and not committed hours tagged by column key for easy
          # sorting and subsequent date allocation.

          report.each_column_range do | range |
            date            = range.min
            date_based_key  = date_to_key_proc.call( date )
            cell            = row.cell!( date_based_key )
            user_total_cell = cell.user_total!( user_id_str )

            has_committed     = true unless ( user_total_cell.committed.zero? )
            has_not_committed = true unless ( user_total_cell.not_committed.zero? )

            hours_array.push( [ user_total_cell.total(), date ] )
            non_zero_col_count += 1 unless ( user_total_cell.committed.zero? )
          end

        end # 'if ( redistribute_hours )'

        # How many zero days, half days and full days do the hours on this
        # row give rise to? We're only interested in distributing days to the
        # columns with hours booked in them, so give the non-zero day count
        # to the distribution function.
        #
        # In turn, it tells us how many of those days should have zero, half
        # or a full workday assigned.

        total    = user_total_for_row.total()
        workdays = ( total * 2 / DAY_LENGTH ).ceil( 0 ) / 2

        zeroes, halves, fulls, spill = uk_org_pond_workday_distribution_for(
          BigDecimal.new( non_zero_col_count ), # Column equivalent to day if daily report
          workdays
        )

        # Take a record of the workday total and spillover for this user/row.

        row_data[ :workday_total ] = fulls + ( halves / 2 )
        row_data[ :spilled_days  ] = spill

        # We know the hours total for this row (computed in 'total' above) and
        # we know the rounded workdays. What's the error? The result will be
        # positive if we over-allocated equivalent hours in workdays, or
        # negative if there are fewer rounded workdays than equivalent booked
        # hours. I.e. positive => overbooked days; negative => underbooked.

        row_data[ :rounding_error ] = workdays * DAY_LENGTH - total

        # The compounded error is the rounding error coupled with the spilled
        # days. Spilled days are things we couldn't assign - unbooked hours.
        # That's an underbooking => negative (see :rounding_error above).

        row_data[ :compounded_error ] = row_data[ :rounding_error ] - spill * DAY_LENGTH

        # The hours array includes hours for every day of the week, including
        # days with no booked hours, or days we must avoid; but redistribution
        # of hours, if requested, has already taken place so avoidable days
        # have zero hours anyway. Since we only calculated a distribution for
        # non-zero hours (see above) we can throw away those array entries.

        hours_array.reject! { | item | item[ 0 ].zero? }

        # Sort by subarray first index => hours ascending.

        hours_array.sort!

        # With the sorted array, "assign" (or rather skip) the lowest hour entry
        # parts which end up with zero workdays, then as we travel to higher and
        # higher hours in the array, drop through assigning the half days, then
        # the full days.

        hours_array.each do | item |
          hours, date = item
          next if hours.zero?

          if ( zeroes > 0 )
            zeroes -= 1
          elsif ( halves > 0 )
            days_data[ date ] = BigDecimal.new( "0.5" )
            halves -= 1
          elsif ( fulls > 0 )
            days_data[ date ] = BigDecimal.new( 1 )
            fulls -= 1
          end
        end

      end # Iterate over users within report row
    end # Iterate over report rows

    label     = report.label.downcase.gsub( ' ', '_' )
    sformat   = '%Y%m%d'   # Compressed ISO-style
    fformat   = '%Y-%m-%d' # Less compressed ISO-style
    stoday    = Date.current.strftime( sformat )
    ftoday    = Date.current.strftime( fformat )
    sstart_at = report.range.min.strftime( sformat )
    fstart_at = report.range.min.strftime( fformat )
    send_at   = report.range.max.strftime( sformat )
    fend_at   = report.range.max.strftime( fformat )
    filename  = "report_workdays_#{ label }_on_#{ stoday }_for_#{ sstart_at }_to_#{ send_at }.csv"
    title     = [
      "#{ report_type.to_s.capitalize } report on #{ ftoday }",
      "From #{ fstart_at }",
      "To #{ fend_at }",
      '(inclusive)'
    ]

    headings  = []
    headings << 'Date' if options[ :include_dates ]
    headings += [ 'Start Time', 'Finish Time' ] if options[ :include_times ]
    headings << 'Total Hours' if options[ :include_rounded_hours ]
    headings += [ 'Days', 'Activity', 'Project', 'Warnings' ]

    include_weekend_rows       = options[ :include_weekend_rows       ]
    include_bank_holiday_names = options[ :include_bank_holiday_names ]

    # Compile the file in memory (see the standard CSV generator for
    # rationale).

    whole_csv_file = CSV.generate do | csv |
      csv << [ "WARNING: Report combines both committed and not committed hours" ] if ( has_committed && has_not_committed )

      if ( options[ :include_title ] )
        csv << [ report.title ] unless report.title.empty?
        csv << title
      end

      users.keys.sort { | x, y | x.name <=> y.name }.each do | user |
        csv << []
        csv << [ "Name: #{ user.name }" ]
        csv << []
        csv << headings

        user_data = users[ user ]

        report.each_column_range do | range |
          date = range.first

          # Write full rows for each task in which the user was involved.
          # If there are several tasks, only use the non-zero ones. If no
          # tasks are non-zero, pick any, so a "n/a" style row is written
          # (else a totally blank row looks like a bug).

          tasks = user_data.keys.sort { | x, y | x.title <=> y.title }

          interesting_tasks = tasks.reject do | task |
            row_data  = user_data[ task ]
            days_data = row_data[ :days ]
            hours     = days_data[ date ]

            hours.nil? || hours.zero?
          end

          interesting_tasks << tasks.first if ( interesting_tasks.empty? )

          dummy_time_offset = 0

          interesting_tasks.each do | task |

            row_data  = user_data[ task ]
            days_data = row_data[ :days ]
            days      = days_data[ date ]

            csv_row   = []

            if ( task == interesting_tasks.first )

              # Complex logic for dates... 

              date_string  = date.strftime( '%a - %d/%m/%Y' )
              empty_we_row = ( nowe && date.cwday > 5         )
              empty_bh_row = ( nobh && bhmap.has_key?( date ) )

              if ( empty_bh_row && include_bank_holiday_names )
                # If this is an empty bank holiday row and we're including bank
                # holiday names, then output the date with the name if so
                # configured, then bail out early for the next row.

                date_string << " (#{ bhmap[ date ] })"
                csv << [ date_string ] if options[ :include_dates ]
                next

              elsif ( include_bank_holiday_names && bhmap.has_key?( date ) )
                # If including bank holiday names and this is a bank holiday,
                # but not an empty one, output the date with the name if so
                # configured, then carry on with row processing.

                date_string << " (#{ bhmap[ date ] })"
                csv_row << date_string if options[ :include_dates ]

              elsif ( empty_we_row && include_weekend_rows )
                # If this is an empty weekend and we're supposed to include
                # weekend rows, output the date if so configured and bail out
                # early for the next row.
                csv << [ date_string ] if options[ :include_dates ]
                next

              elsif ( empty_we_row )
                # If this is an empty weekend row but (due to above 'ifs') we
                # are not including empty weekend rows, move to the next row
                # without any output.
                next

              else
                # Otherwise, output the date if so configured and carry on
                # with row processing.
                csv_row << date_string if options[ :include_dates ]

              end

            else
              csv_row << '' if options[ :include_dates ]

            end

            if ( days.nil? || days.zero? )
              csv_row += uk_org_pond_get_row( options )
            else
              csv_row += uk_org_pond_get_row( options, days, task, dummy_time_offset )

              # The time offset is used for multiple rows on the same day for
              # non-zero days worked on more than one task (in a daily report,
              # this should really only be 0.5 each, else we exceed 1 day in
              # the row; however, rounding may mean that can happen
              # legitimately). In each case, we want the dummy start time to be
              # offset / advanced by the amount on the current row, plus one
              # hour. For a half-day that'd equate to lunch hour, for a full
              # day lunch hour is catered for in the "...get_row" call already,
              # so it'd count as an evening hour break.

              dummy_time_offset += ( days * DUMMY_HOURS_DAY_LENGTH + 1 ).hours
            end

            csv << csv_row

          end # Iterate over the tasks in which a user was involved
        end # Iterate over report's date range

        # Do totals and rounding warnings.

        error = big_zero
        total = big_zero

        user_data.keys.sort { | x, y | x.title <=> y.title }.each do | task |
          row_data   = user_data[ task ]
          task_error = row_data[ :compounded_error ] || big_zero
          task_total = row_data[ :workday_total    ] || big_zero

          error += task_error
          total += task_total
        end

        csv_row  = []
        csv_row << ''         if options[ :include_dates ]
        csv_row += [ '', '' ] if options[ :include_times ]

        if options[ :include_rounded_hours ]
          if ( total.zero? )
            csv_row << '0.0'
          else
            csv_row << "%.1f" % ( total * DUMMY_HOURS_DAY_LENGTH )
          end
        end

        if ( total.zero? )
          csv_row << '0.0'
        else
          csv_row << "%.1f" % total
        end

        # "(totals)" shows under "Activity", "Project" is left empty.

        csv_row += [ '(totals)', '' ]

        # Make sure the over/under-book warnings are in a separate column
        # after the project, so it's easy to delete these in a spreadsheet
        # editor if required.

        if ( error < 0 )
          csv_row << "#{ error} recorded hour(s) not included"
        elsif ( error > 0 )
          csv_row << "#{ error} hour(s) over-booked"
        end

        csv << csv_row

      end # Iterate over compiled user data
    end # CSV generation block

    # Send the CSV data all in one go.

    send_data(
      whole_csv_file,
      {
        :type        => 'text/csv',
        :disposition => 'attachment',
        :filename    => filename
      }
    )

    # Indicate success.

    return nil
  end

  # Private methods are contained herein. Note the prefixes used on all
  # method names to avoid ReportsController collisions.
  #
  # See the namespace documentation of the base TrackRecordReportGenerator
  # module for more details.
  #
  def self.extended( base )
    class << base
    private

      # Given a number of hours that need to be distributed over a number of
      # days (e.g. because weekend hours are booked and they need to be moved
      # to week days), call here. The hours are distributed with quarter-hour
      # quantisation across the number of days given. The results are always
      # positive (never want to "subtract time" from a day).
      #
      # There's no easy way to do this. Calculating (for example) a rounded
      # average for most days and placing the resulting error onto the last
      # day gives bad answers - e.g. imagine 100 days, with 24 hours to move.
      # You can't put 0.25 on the first 99 days as that gives 25 days, with a
      # negative value for the last day. If you instead put zero hours on the
      # first 99 days, the resulting error for the last is all 24 hours.
      #
      # Instead, you have to step through for each day and keep track of the
      # quantisation error, distributing it to the next day(s). Herein, a
      # very simple algorithm is used for best possible speed. It tends to
      # distribute more hours in the earlier days and less in the later (in
      # terms of very small 0.25 hour variations).
      #
      # Returns an array with the addition to use on each of the days. The
      # order in which the caller processes that array and the calendar days
      # on which the additions may be applied is up to the caller to choose.
      #
      def uk_org_pond_redistribution_amounts_for( hours_to_move, days_to_receive )

        adjustments   = []
        exact_per_day = hours_to_move / days_to_receive
        error         = BigDecimal.new( 0 )

        days_to_receive.times do
          quantised = ( ( exact_per_day - error ) * 4 ).ceil( 0 ) / 4
          adjustments << quantised
          error += quantised - exact_per_day
        end

        adjustments
      end

      # Given a number of calendar days over which a number of working
      # days must be distributed, return information on the number of
      # calendar days that should be allocated zero equivalent working
      # days, half a working day, or a full working day.
      #
      # Returns an array with the following elements, in the order
      # shown:
      #
      #  - zeroes; number of calendar days to get no work days
      #  - halves; number of calendar days to get half a work day
      #  - fulls;  number of calendar days to get a full work day
      #  - spill;  the number of work days left over
      #
      # The "spill" value is non-zero if you ask for more work days than
      # there are calendar days (so "spill" is the difference between
      # those two numbers, for that specific case, else always zero).
      #
      # For good accuracy, ensure you pass BigDecimals only. Calendar
      # days must be an integer value as a BigDecimal, while the work
      # day count must give a value rounded to half-days.
      #
      def uk_org_pond_workday_distribution_for( calendar_days_of_work, workdays )

        # Simple example:
        #
        # X workdays across Y calendar days
        # ==========================================================
        # 4                 3 => 1 full, 3 spilled over
        # 4                 5 => 3 full, two halves
        # 4                 7 => 1 full, six halves
        # 4                 9 => 0 full, eight halves, one zero

        # "extra_days":
        #
        # Number of calendar days there are more than workdays. If this is
        # negative there are more workdays than calendar days, so all we
        # can do is distribute full days for every calendar day and spill
        # the remainder over as something we can't allocate.
        #
        # If there are as many or more days left over than there are
        # workdays, then in other words there were at least twice as many
        # calendar days as workdays. So, spread everything out in half
        # days and some zero days.
        #
        # If somewhere in between, calculate the half day and full day
        # allocation. There will be no zero days or spillover.
        #
        # Note how the simple maths copes in passing with correct results
        # for half-workdays specified in "workdays", provided that
        # "calendar_days_of_work" is always an integer.

        extra_days = calendar_days_of_work - workdays
        big_zero   = BigDecimal.new( 0 )

        if ( extra_days < 0 )
          zeroes = big_zero
          halves = big_zero
          fulls  = calendar_days_of_work
          spill  = -extra_days
        elsif ( extra_days >= workdays )
          zeroes = extra_days - workdays
          halves = workdays * 2
          fulls  = big_zero
          spill  = big_zero
        else
          zeroes = big_zero
          halves = extra_days * 2
          fulls  = workdays - extra_days
          spill  = big_zero
        end

        [ zeroes, halves, fulls, spill ]
      end

      # Get row data for the partial row includin start and end time,
      # rounded hours, days, task name and project name - subject to
      # provided options. Returns an array that can be added to a CSV row.
      # Pass the options, with keys ":include_times" for dummy start/end
      # times, ":include_rounded_hours" for dummy hours having a value of
      # 'true' or false/omitted to include/exclude those things,
      # respectively; then pass an optional number of days and task. If
      # the days count is zero/omitted the related times and hours will be
      # returned as "n/a". If the task is nil/omitted then its title will
      # be returned as "n/a".
      #
      # Finally, pass an optional time offset. If writing dummy times,
      # which normally start at 9:00am, this value is added to all such
      # times. It means you can provide the illusion of continuity from
      # one row to another by advancing a time offset at each row based
      # on the number of (presumably half-)days work represented by it.
      #
      def uk_org_pond_get_row( options, days = 0, task = nil, time_offset = 0.hours )
        csv_row = []
        
        if options[ :include_times ]
          if ( days.zero? )
            csv_row += [ 'n/a', 'n/a' ]
          else
            start  = Time.new( 2000, 1, 1, 9, 0, 0, 0 ) + time_offset
            finish = start + ( ( days * DUMMY_HOURS_DAY_LENGTH ) + ( days >= 1 ? 1 : 0 ) ).hours # "+ 1" for "lunch hour" in a full day worked
            fmt    = "%H:%M:%S"

            csv_row += [ start.strftime( fmt ), finish.strftime( fmt ) ]
          end
        end

        if options[ :include_rounded_hours ]
          if ( days.zero? )
            csv_row << 'n/a'
          else
            csv_row << "%.1f" % ( days * DUMMY_HOURS_DAY_LENGTH )
          end
        end

        # Actual days value

        if ( days.zero? )
          csv_row << 'n/a'
        else
          csv_row << "%.1f" % days
        end

        # Task name and project

        if ( task.nil? )
          csv_row << 'n/a'
        else
          csv_row << task.title
        end

        if ( task.nil? || task.project.nil? )
          csv_row << 'n/a'
        else
          csv_row << task.project.title
        end

        return csv_row
      end

      # Return a form element ID to use for the "include title" check box
      # of a given report type.
      #
      def uk_org_pond_include_title_id_for_type( type )
        "titles_#{ type }"
      end

      # Return a form element ID to use for the "per-month" radio button
      # option of a given report type.
      #
      def uk_org_pond_month_rounding_id_for_type( type )
        "monthly_#{ type }"
      end

      # Return a form element ID to use for the "all-time" radio button
      # option of a given report type.
      #
      def uk_org_pond_range_rounding_id_for_type( type )
        "whole_range_#{ type }"
      end

      # Return a form element ID to use for the "carry rounding errors"
      # check box of a given report type.
      #
      def uk_org_pond_carry_rounding_id_for_type( type )
        "carry_rounding_#{ type }"
      end

      # Return a form element ID to use for the "redistribute weekends"
      # check box of a given report type.
      #
      def uk_org_pond_redistribute_weekends_id_for_type( type )
        "redistribute_weekends_#{ type }"
      end

      # Return a form element ID to use for the "redistribute bank
      # holidays" check box of a given report type.
      #
      def uk_org_pond_redistribute_bank_holidays_id_for_type( type )
        "redistribute_bank_holidays_#{ type }"
      end

      # Return a form element ID to use for the "include dates column"
      # check box of a given report type.
      #
      def uk_org_pond_include_dates_id_for_type( type )
        "dates_#{ type }"
      end

      # Return a form element ID to use for the "include times column"
      # check box of a given report type.
      #
      def uk_org_pond_include_times_id_for_type( type )
        "times_#{ type }"
      end

      # Return a form element ID to use for the "include rounded hours
      # column" check box of a given report type.
      #
      def uk_org_pond_include_rounded_hours_id_for_type( type )
        "rounded_hours_#{ type }"
      end

      # Return a form element ID to use for the "include weekend rows"
      # check box of a given report type.
      #
      def uk_org_pond_include_weekend_rows_id_for_type( type )
        "weekend_rows_#{ type }"
      end

      # Return a form element ID to use for the "include holiday names"
      # check box of a given report type.
      #
      def uk_org_pond_include_bank_holiday_names_id_for_type( type )
        "bank_holiday_names_#{ type }"
      end

    end # class << base
  end   # def self.extended( base )
end     # module TrackRecordReportGenerator::UkOrgPondCSV
