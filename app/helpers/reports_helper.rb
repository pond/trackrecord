########################################################################
# File::    reports_helper.rb
# (C)::     Hipposoft 2008
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
      @all   = "#{ week }, Mon #{ Timesheet.date_for( year, week, TimesheetRow::FIRST_DAY ) } - Sun #{ Timesheet.date_for( year, week, TimesheetRow::LAST_DAY ) }"
    end

    attr_reader( :start, :end, :all, :id )
  end

  # Helper class for ReportYear and reporthelp_month_selection.

  class ReportMonth
    def initialize( year, month )
      @id    = "#{ year }_#{ month }"
      @start = "#{ month } (start of #{ Date::MONTHNAMES[ month ] } #{ year })"
      @end   = "#{ month } (end of #{ Date::MONTHNAMES[ month ] } #{ year })"
      @all   = "#{ month }, #{ Date::MONTHNAMES[ month ] } #{ year }"
    end

    attr_reader( :start, :end, :all, :id )
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

      # Work out the months, again limited as above.

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

  # Use the Calendar Date Select plug-in to generate a selector for the
  # start time of a report. Pass the form instance upon which to operate.
  #
  def reporthelp_start_time( form )
    return form.calendar_date_select(
      :range_start,
      {
        :embedded   => false,
        :year_range => Timesheet.used_range()
      }
    )
  end

  # Use the Calendar Date Select plug-in to generate a selector for the
  # end time of a report. Pass the form instance upon which to operate.

  def reporthelp_end_time( form )
    return form.calendar_date_select(
      :range_end,
      {
        :embedded   => false,
        :year_range => Timesheet.used_range()
      }
    )
  end

  # Return HTML suitable for inclusion in a form which provides
  # a pull-down menu of years for the full permitted time range
  # subdivided into months. Pass the form being constructed and
  # ":range_month_start" or ":range_month_end".
  #
  def reporthelp_month_selection( form, method )
    start_or_end = ( method == :range_month_start ) ? :start : :end

    form.grouped_collection_select(
      method,
      get_year_array(), # Use years for groups
      :months,          # A years's "months" method returns its month list
      :title,           # Use the year 'title' for the group labels
      :id,              # A month's "id" method returns the value for an option tag
      start_or_end,     # A month's "start" or "end" method is used for the option contents
      {
        :include_blank => '-'
      }
    )
  end

  # Return HTML suitable for inclusion in a form which provides
  # a pull-down menu of years for the full permitted time range
  # subdivided into weeks. Pass the form being constructed and
  # ":range_week_start" or ":range_week_end".
  #
  def reporthelp_week_selection( form, method )
    start_or_end = ( method == :range_week_start ) ? :start : :end

    form.grouped_collection_select(
      method,
      get_year_array(), # Use years for groups
      :weeks,           # A years's "weeks" method returns its week list
      :title,           # Use the year 'title' for the group labels
      :id,              # A week's "id" method returns the value for an option tag
      start_or_end,     # A week's "start" or "end" method is used for the option contents
      {
        :include_blank => '-'
      }
    )
  end

  # Return HTML suitable for inclusion in a form which provides
  # options such as "this month" or "one week ago" in a selection
  # list. Pass the form being constructed and ":range_one_month"
  # or ":range_one_week".
  #
  def reporthelp_one_selection( form, method )
    now = DateTime.now.utc

    if ( method == :range_one_week )
      strings = [
        apphelp_view_hint( :last_week,     SavedReportsController ),
        apphelp_view_hint( :this_week,     SavedReportsController ),
        apphelp_view_hint( :two_weeks_ago, SavedReportsController ),
      ]
      dates = [
        now - 1.week,
        now,
        now - 2.weeks
      ]
      objects = dates.map do | date |
        ReportWeek.new( date.year, date.cweek )
      end
    else
      strings = [
        apphelp_view_hint( :last_month,     SavedReportsController ),
        apphelp_view_hint( :this_month,     SavedReportsController ),
        apphelp_view_hint( :two_months_ago, SavedReportsController ),
      ]
      dates = [
        now - 1.month,
        now,
        now - 2.months
      ]
      objects = dates.map do | date |
        ReportMonth.new( date.year, date.month )
      end
    end

    keys  = [ "last", "this", "two" ]
    array = strings.map.with_index do | string, index |
      o       = OpenStruct.new
      o.value = keys[ index ]
      o.text  = string % objects[ index ].all # The "all" method on a ReportWeek or ReportMonth gives its name/date in a suitable format
      o
    end

    form.collection_select(
      method,
      array,
      :value,
      :text,
      {
        :include_blank => '-'
      }
    )
  end

  # Return HTML suitable for inclusion in the form passed in the
  # first parameter (i.e. the 'f' in "form for ... do |f|" ), which
  # provides a selection list allowing the user to choose a report
  # frequency (weekly, monthly etc.).
  #
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
        'reportable_user_ids',
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
      return "by #{ h( item.name ) }".html_safe()
    else
      return "on '#{ h( item.augmented_title ) }'".html_safe()
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
    if ( calculator.try( :has_hours? ) )
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

      return output.html_safe()
    else
      return ( show_zero ? '0' : '&nbsp;' ).html_safe()
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

    return output.html_safe()
  end

  #############################################################################
  # LIST VIEWS
  #############################################################################

  # List helper - owner of the given report

  def reporthelp_owner( report )
    return link_to( report.user.name, user_path( report.user ) )
  end

  # List helper - formatted 'updated at' date for the given report

  def reporthelp_updated_at( report )
    return apphelp_date( report.updated_at )
  end

  # List helper - formatted start date for the given report

  def reporthelp_start_date( report )
    if ( report.range_start_cache.class != Date )
      apphelp_view_hint( "date_start_#{ report.range_start_cache }" )
    else
      apphelp_date( report.range_start_cache )
    end
  end

  # List helper - formatted end date for the given report

  def reporthelp_end_date( report )
    if ( report.range_end_cache.class != Date )
      apphelp_view_hint( "date_end_#{ report.range_end_cache }" )
    else
      apphelp_date( report.range_end_cache )
    end
  end

  # Return appropriate list view actions for the given report

  def reporthelp_actions( report )
    if ( @current_user.admin? || report.user_id == @current_user.id )
      return [
        {
          :title => :delete,
          :url   => delete_user_saved_report_path( :user_id => report.user_id, :id => "%s" )
        },
        {
          :title => :edit,
          :url   => edit_user_saved_report_path( :user_id => report.user_id, :id => "%s" )
        },
        {
          :title => :copy,
          :url   => user_saved_report_copy_path( :user_id => report.user_id, :saved_report_id => "%s" )
        },
        {
          :title => :show,
          :url   => user_saved_report_path( :user_id => report.user_id, :id => "%s" )
        },
      ]
    else
      return []
    end
  end

  # Return an input element and label as part of a form used to export
  # a report. Pass the submodule of TrackRecordReportGenerator for
  # which options are being generated and the array entry from the
  # option data the submodule provides in "invocation_options_for".
  #
  def reporthelp_export_option( submodule, option )
    prefix = submodule.name.underscore
    kind   = option.keys.first
    data   = option.values.first

    case kind
      when :checkbox
        id      = "#{ prefix }[#{ data[ :id ] }]"
        output  = check_box_tag( id, "1", data[ :checked ] )
        output << label_tag( id, data[ :label ] )

      when :radio
        id     = data[ :id ]
        name   = "#{ prefix }[#{ data[ :name ] }]"
        output = radio_button_tag( name, id, data[ :checked ] )
        output << label_tag( "#{ name }_#{ id }", data[ :label ] )

      else
        ""
    end
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
