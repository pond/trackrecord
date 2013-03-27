########################################################################
# File::    reports_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Support functions for views related to report generation.
#           See controllers/reports_controller.rb for more.
# ----------------------------------------------------------------------
#           18-Feb-2008 (ADH): Created.
########################################################################

module ReportsHelper

  include TrackRecordReport

  # Helper class for ReportYear and reporthelp_week_selection.

  class ReportWeek
    def initialize( year, week )
      @id    = "#{ year }_#{ week }"
      @start = "#{ week } (starts Mon #{ Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY ) })"
      @end   = "#{ week } (ends Sun #{ Timesheet.date_for( year, week, TimesheetRow::LAST_DAY ) })"
    end

    attr_reader( :start, :end, :id )
  end

  # Helper class for ReportYear and reporthelp_month_selection.

  class ReportMonth
    def initialize( year, month )
      @id    = "#{ year }_#{ month }"
      @start = "#{ month } (start of #{ Date::MONTHNAMES[ month ] } #{ year })"
      @end   = "#{ month } (end of #{ Date::MONTHNAMES[ month ] } #{ year })"
    end

    attr_reader( :start, :end, :id )
  end

  # Helper class for reporthelp_week_selection and reporthelp_month_selection.
  # Initialize by passing a year for a full set of months, or by passing a
  # year and a range of accurate dates. If the year matches the first or last
  # date in that range, then the months associated with the year will be
  # restricted according to the matching start and/or end date. The range, if
  # given, MUST have a "first" date which is earlier in the year, or at worst
  # the same date as the "last" date (i.e. don't pass in "backwards" ranges).
  #
  # Commercial numbered weeks within which a given date falls may start or end
  # on the previous or next year. If the caller provides a limiting date range
  # that exhibits this (e.g. passes in 31st December 2008, which actually lies
  # in week 1, 2009) then the ReportYear object can do nothing other than
  # represent a full set of its own numbered weeks. If you want to create an
  # object for the extra year, where applicable, you must do so manually.
  #
  class ReportYear
    def initialize( year, date_range = nil )
      @title  = year.to_s
      @weeks  = []
      @months = []

      # "limit" is set if the object is being built for the current year.
      # Weeks and months are checked and any that lie in the future are
      # not included.

      today = Date.current
      limit = ( year == today.year )
      range = ( 1..( Timesheet.get_last_week_number( year ) ) )

      # Work out the weeks, limited as above, or perhaps by an optional date
      # range passed in by the caller.

      range.each do | week |
        first_day_of_week = Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY, true )
        last_day_of_week  = first_day_of_week + 6

        break if (
          ( limit      and first_day_of_week > today           ) or
          ( date_range and first_day_of_week > date_range.last )
        )

        next if (
          ( date_range and last_day_of_week < date_range.first )
        )

        @weeks.unshift( ReportWeek.new( year, week ) )
      end

      # Work out hte months, again limited as above.

      ( 1..12 ).each do | month |

        break if (
          ( limit      and month > today.month           ) or
          ( date_range and month > date_range.last.month and date_range.last.year == year )
        )

        next if (
          ( date_range and month < date_range.first.month and date_range.first.year == year  )
        )

        @months.unshift( ReportMonth.new( year, month ) )
      end
    end

    attr_reader( :title, :weeks, :months )
  end

  # Use the Calendar Date Select plug-in to generate a selector for
  # the start time of a report.

  def reporthelp_start_time
    return calendar_date_select(
      :report,
      :range_start,
      {
        :embedded   => false,
        :year_range => Timesheet.used_range(),
        :size       => 25
      }
    )
  end

  # Use the Calendar Date Select plug-in to generate a selector for
  # the end time of a report.

  def reporthelp_end_time
    return calendar_date_select(
      :report,
      :range_end,
      {
        :embedded   => false,
        :year_range => Timesheet.used_range(),
        :size       => 24
      }
    )
  end

  # Return HTML suitable for inclusion in a form which provides
  # a pull-down menu of years for the full permitted time range
  # subdivided into months. Pass the current item to select or nil
  # for none, then 'true' for a start time menu, else an end time
  # menu.
  #
  def reporthelp_month_selection( to_select, is_start )
    method = is_start ? :start : :end
    years  = get_year_array()

    data = "<select id=\"report_range_month_#{method}\" name=\"report[range_month_#{method}]\">"
    data << '<option value="">-</option>'
    data << option_groups_from_collection_for_select(
      years,   # Use years for groups
      :months, # A years's "months" method returns its month list
      :title,  # Use the year 'title' for the group labels
      :id,     # A month's "id" method returns the value for an option tag
      method,  # A month's "start" or "end" method is used for the option contents
      to_select
    )
    return data << '</select>'
  end

  # Return HTML suitable for inclusion in a form which provides
  # a pull-down menu of years for the full permitted time range
  # subdivided into weeks. Pass 'true' for a start time menu,
  # else an end time menu.

  def reporthelp_week_selection( to_select, is_start )
    method = is_start ? :start : :end
    years  = get_year_array()

    data = "<select id=\"report_range_week_#{method}\" name=\"report[range_week_#{method}]\">"
    data << '<option value="">-</option>'
    data << option_groups_from_collection_for_select(
      years,  # Use years for groups
      :weeks, # A years's "weeks" method returns its week list
      :title, # Use the year 'title' for the group labels
      :id,    # A week's "id" method returns the value for an option tag
      method, # A week's "start" or "end" method is used for the option contents
      to_select
    )
    return data << '</select>'
  end

  # Return HTML suitable for inclusion in the form passed in the
  # first parameter (i.e. the 'f' in "form for ... do |f|" ), which
  # provides a selection list allowing the user to choose a report
  # frequency (weekly, monthly etc.).

  def reporthelp_frequency_selection( form )
    collection = []

    Report.labels.each_index do | index |
      collection.push( [ Report.labels[ index ], index ] )
    end

    form.select( :frequency, collection )
  end

  # Return HTML suitable for inclusion in the form passed in the
  # first parameter (i.e. the 'f' in "form for ... do |f|" ), based
  # on the user array given in the second parameter, which provides:
  #
  # * A <select> tag with options listing all users in the array
  #   in the order in which they are stored in that array.
  #
  # * An empty string if the input users array is itself empty.
  #
  def reporthelp_user_selection( form, users )
    if ( users.empty? )
      return ''
    else
      return apphelp_collection_select(
        form,
        'user_ids',
        users,
        :id,
        :name
      )
    end
  end

  # Generate a sort field selector menu for the given form which will use
  # the given method to set the chosen option in the report - one of
  # ":customer_sort_field", ":project_sort_field" or ":task_sort_field".
  #
  def reporthelp_sorting_selector( form, method )
    return apphelp_select(
      form,
      method,
      [
        [ 'Sort by name',          'title'      ],
        [ 'Sort by code',          'code'       ],
        [ 'Sort by addition date', 'created_at' ]
      ],
      false
    )
  end

  # Generate a menu for the given form allowing the user to choose a grouping
  # option.
  #
  def reporthelp_grouping_selector( form )
    return apphelp_select(
      form,
      :task_grouping,
      [
        [ 'No special grouping',                'default'  ],
        [ 'Group billable tasks together',      'billable' ],
        [ 'Group active tasks together',        'active'   ],
        [ 'Group both kinds of tasks together', 'both'     ]
      ],
      false
    )
  end

  # Pass a hash. The ":item" entry is read. If a User, a string of
  # "by <name>" is returned. Otherwise, a string of "on '<title>'" is
  # returned. Useful for indicating hours are done by a user, or were
  # worked on some task.

  def reporthelp_work_breakdown_item_name( item )
    item = item[ :item ]

    if ( item.class == User )
      return "by #{ h( item.name ) }"
    else
      return "on '#{ h( item.augmented_title ) }'"
    end
  end

  # Return HTML suitable for an 'hours' field which gives a total amount,
  # then a committed and not-committed amount wrapped in SPANs to give the
  # correct committed/uncommitted text styles. If the overall total time
  # is zero, "&nbsp;" is returned instead. Pass any object subclassing
  # TrackRecordReport::ReportElementaryCalculator and, optionally, 'true'
  # to show "0.0" rather than "&nbsp;" in the zero hours total case.
  #
  def reporthelp_hours( calculator, show_zero = false )

    if ( calculator.has_hours? )
      output  = ''
      output << apphelp_terse_hours( calculator.total ) if ( @report.include_totals != false )
      output << ' (' if ( @report.include_totals != false and ( @report.include_committed != false or @report.include_not_committed != false ) )

      if ( @report.include_committed != false )
        output << '<span class="timesheet_committed">'
        output << apphelp_terse_hours( calculator.committed )
        output << '</span>'
      end

      output << '/' if ( @report.include_committed != false and @report.include_not_committed != false )

      if ( @report.include_not_committed != false )
        output << '<span class="timesheet_not_committed">'
        output << apphelp_terse_hours( calculator.not_committed )
        output << '</span>'
      end

      output << ')' if ( @report.include_totals != false and ( @report.include_committed != false or @report.include_not_committed != false ) )

      return output
    else
      return ( show_zero ? '0' : '&nbsp;' )
    end
  end

  # Report a terse number of hours with an 'overrun' span if negative or a
  # 'no_overrun' span if >= 0 in two sections separated by a "/" - the idea
  # is to pass actual and potential remaining hours for a task in here.

  def reporthelp_decorated_hours( actual, potential )
    class_name  = actual    < 0 ? 'overrun' : 'no_overrun'
    output      = "<strong><span class=\"#{ class_name }\">#{ apphelp_terse_hours( actual ) }</span> / "
    class_name  = potential < 0 ? 'overrun' : 'no_overrun'
    output     << "<span class=\"#{ class_name }\">#{ apphelp_terse_hours( potential ) }</span></strong>"

    return output
  end

  # For a report 'show' view, generate a series of hidden fields that carry all
  # information about a report so that a 'new' view, or another report creation
  # operation, can progress with the same parameters as the current item. Pass
  # the wrapping form object reference ("f" in "form_for :report... do | f |").

  def reporthelp_hidden_fields( form )
    output  = form.hidden_field( :range_start           )
    output << form.hidden_field( :range_end             )
    output << form.hidden_field( :range_week_start      )
    output << form.hidden_field( :range_week_end        )
    output << form.hidden_field( :range_month_start     )
    output << form.hidden_field( :range_month_end       )
    output << form.hidden_field( :frequency             )
    output << form.hidden_field( :task_filter           )
    output << form.hidden_field( :task_grouping         )
    output << form.hidden_field( :task_sort_field       )
    output << form.hidden_field( :project_sort_field    )
    output << form.hidden_field( :customer_sort_field   )
    output << form.hidden_field( :include_totals        )
    output << form.hidden_field( :include_committed     )
    output << form.hidden_field( :include_not_committed )
    output << form.hidden_field( :exclude_zero_rows     )
    output << form.hidden_field( :exclude_zero_cols     )

    @report.users.each_index do | index |
      user = @report.users[ index ]
      output << hidden_field_tag( "report[user_ids][#{ index }]", user.id.to_s )
    end

    @report.tasks.each_index do | index |
      task = @report.tasks[ index ]
      output << hidden_field_tag( "report[task_ids][#{ index }]", task.id.to_s )
    end

    return output
  end

  def reporthelp_shortcut_path
    "#{ report_shortcut_path }?#{ { 'report' => params[ 'report' ] } .to_query }"
  end

private # Meaninless in a module but put here as a marker

  # Return an array of integers representing years, from most recent to least
  # recent (descending numerical order), spanning the full range of work
  # packets in the database. The catch is that working weeks are accounted for
  # and the years returned capture the work packet range, rounded to the start
  # of a commercial week and end of a commercial week at either extent. For
  # some systems, work packets may start mid-week on a week at the edge of a
  # year which, rounded, actually starts or ends in the previous or next year
  # overall. This function accounts for that.
  #
  def get_year_array
    accurate_range = Timesheet.used_range( true )

    # Does the range's start date lie within a commerical week which actually
    # starts in the previous year?

    first_date        = accurate_range.first
    first_day_of_week = Timesheet.date_for( first_date.year, first_date.cweek, TimesheetRow::FIRST_DAY, true )
    start_year        = first_day_of_week.year

    # Similar logic for the range's last date.

    if ( accurate_range.last > Date.today ) # Implies no work packets => Timesheet.used_range returned an allowed range instead.
      last_date = Date.today
    else
      last_date = accurate_range.last
    end

    last_day_of_week = Timesheet.date_for( last_date.year, last_date.cweek, TimesheetRow::LAST_DAY, true )
    end_year         = last_day_of_week.year

    years      = []
    year_range = ( start_year..end_year )

    # Build the years array backwards so newer dates are encountered
    # first - a user is more likely to be interested in current data
    # than in ancient history.

    year_range.each do | year |
      years.unshift( ReportYear.new( year, accurate_range ) )
    end

    return years
  end

end
