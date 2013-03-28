########################################################################
# File::    timesheets_helper.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Support functions for views related to Timesheet objects.
#           See controllers/timesheets_controller.rb for more.
# ----------------------------------------------------------------------
#           07-Jan-2008 (ADH): Created.
########################################################################

module TimesheetsHelper

  #############################################################################
  # GENERAL
  #############################################################################

  # Return HTML suitable for inclusion in the form passed in the
  # first parameter (i.e. the 'f' in "form for ... do |f|" ), based
  # on the timesheet given in the second parameter, which provides:
  #
  # * A <select> tag listing available week numbers, with dates,
  #   which may be assigned to the timesheet.
  #
  # * An empty string if there are no free weeks - the edit view
  #   should never have been shown, but never mind...!

  def timesheethelp_week_selection( form, timesheet )
    weeks = timesheet.unused_weeks();

    if ( weeks.empty? )
      return ''.html_safe()
    else
      return form.select(
        :week_number,
        weeks.collect do | week |
          [
            "Week #{ week } (#{ Timesheet.date_for( timesheet.year, week, TimesheetRow::FIRST_DAY ) })",
            week
          ]
        end
      )
    end
  end

  # Return an array of tasks suitable for timesheet row addition.
  # Will be empty if all tasks are already included, or no tasks are
  # available for any other reason. Pass the timesheet of interest.
  #
  # Note that tasks with no project, or tasks with a project with no
  # customer, are excluded from the list.
  #
  def timesheethelp_tasks_for_addition( timesheet )
    tasks = @current_user.active_permitted_tasks - timesheet.tasks

    tasks.reject do | task |
      task.project_id.nil? || task.project.customer_id.nil?
    end
  end

  # Return HTML suitable for inclusion in the form passed in the
  # first parameter (i.e. the 'f' in "form for ... do |f|" ), based
  # on the task array given in the second parameter, which provides:
  #
  # * A <select> tag with options listing all tasks not already used
  #   by this timesheet.
  #
  # * An empty string if the timesheet already has rows for every
  #   task presently stored in the system.
  #
  def timesheethelp_task_selection( form, tasks )
    if ( tasks.empty? )
      return ''.html_safe()
    else
      Task.sort_by_augmented_title( tasks )

      return apphelp_collection_select(
        form,
        'task_ids',
        tasks,
        :id,
        :augmented_title
      )
    end
  end

  # Output HTML suitable as a label to show whether or not the
  # given timesheet is committed or otherwise. The second parameter
  # lets you override the given timesheet and force the generation of
  # a committed (pass 'true') or not committed (pass 'false') label.

  def timesheethelp_commit_label( timesheet, committed = nil )
    committed = @timesheet.committed if ( committed.nil? )
    return (
      committed ? '<span class="timesheet_committed">Committed</span>' :
                  '<span class="timesheet_not_committed">Not Committed</span>'
    ).html_safe()
  end

  # Return the timesheet description, or 'None' if it is empty.

  def timesheethelp_always_visible_description( timesheet )
    if ( timesheet.description.nil? or timesheet.description.empty? )
      des = 'None'
    else
      des = h( timesheet.description )
    end

    return des.html_safe()
  end

  # Return a year chart for the given year. This is a complete table of
  # months down the left and week numbers with dates of the first week in
  # individual cells along the monthly rows. Months indicate the month of
  # the first day of the week in that year, so in week 1 will often be for
  # the previous year (which is clearly indicated in the table). Cell
  # colours indicate the condition of a timesheet for each week with links
  # to edit the existing timesheets or create new timesheets as necessary.

  def timesheethelp_year_chart( year )
    week_range = 1..( Timesheet.get_last_week_number( year ) )
    first_day  = TimesheetRow::FIRST_DAY
    months     = Hash.new

    # Compile a hash keyed by year/month number which points to arrays of
    # week numbers with start date. The length of each keyed entry indicates
    # the number of weeks in that month. Key names are sortable by default
    # sort function behaviour to provide a date-ascending list.

    week_range.each do | week |
      start_date = Timesheet.date_for( year, week, first_day, true )
      key        = "#{ start_date.year }-%02i" % start_date.month
      data       = { :week => week, :start_date => start_date }

      if ( months[ key ].nil? )
        months[ key ] = [ data ]
      else
        months[ key ].push( data )
      end
    end

    # Now run through the collated data to build the chart, working on the
    # basis of the sorted keys in the hash for each row and a maximum of 5
    # weeks in any of those rows. Blank entries are put at the start of a
    # row to make up 5 columns in case there aren't that many weeks in that
    # particular month.

    keys      = months.keys.sort
    row_class = 'even'
    output    = "<table class=\"timesheet_chart\">\n"
    output   << "  <tr><th>Month</th><th colspan=\"5\">Week start date and number</th></tr>\n"

    keys.each do | key |
      data      = months[ key ]
      row_start = data[ 0 ][ :start_date ]

      heading = "#{ Date::MONTHNAMES[ row_start.month ] } "<<
                "#{ row_start.year }"

      row_class = ( row_class == 'even' ) ? 'odd' : 'even'
      row_class = row_class + ' last' if ( key == keys.last )

      output << "  <tr class=\"#{ row_class }\">\n"
      output << "    <td class=\"timesheet_chart_month\">#{ heading }</td>\n"
      output << "    <td>&nbsp;</td>\n" * ( 5 - data.length )

      data.each do | week |
        timesheet = Timesheet.find_by_user_id_and_year_and_week_number(
          @current_user.id,
          year,
          week[ :week ]
        )

        classnm = 'centred'
        content = "#{ week[ :start_date ].day }" <<
                  " #{ Date::ABBR_MONTHNAMES[ week[ :start_date ].month ] }" <<
                  " (#{ week[ :week ] })"

        if ( timesheet )
          if ( timesheet.committed )
            classnm = 'centred committed'
            content = link_to( content.html_safe(), timesheet_path( timesheet ) )
          else
            classnm = 'centred not_committed'
            content = link_to( content.html_safe(), edit_timesheet_path( timesheet ) )
          end
        else
          content = button_to(
            content.html_safe(),
            {
              :action      => :create,
              :method      => :post,
              :year        => year,
              :week_number => week[ :week ]
            }
          )
        end

        output << "    <td class=\"#{ classnm }\">#{ content }</td>\n"
      end

      output << "  </tr>\n"
    end

    return ( output << '</table>' ).html_safe()
  end

  #############################################################################
  # LIST VIEWS
  #############################################################################

  # List helper - owner of the given timesheet

  def timesheethelp_owner( timesheet )
    return link_to( timesheet.user.name, user_path( timesheet.user ) )
  end

  # List helper - formatted 'updated at' date for the given timesheet

  def timesheethelp_updated_at( timesheet )
    return apphelp_date( timesheet.updated_at )
  end

  # List helper - formatted 'committed at' date for the given timesheet

  def timesheethelp_committed_at( timesheet )
    if ( timesheet.committed )
      return apphelp_date( timesheet.committed_at )
    else
      return 'Not committed'
    end
  end

  # List helper - number of hours in total recorded in the given timesheet

  def timesheethelp_hours( timesheet )
    return apphelp_string_hours( timesheet.total_sum.to_s, '-', '-' )
  end

  # Return appropriate list view actions for the given timesheet

  def timesheethelp_actions( timesheet )
    if ( @current_user.admin? )
      return [ 'edit', 'delete', 'show' ]
    elsif ( @current_user.manager? or timesheet.user_id == @current_user.id )
      return [ 'show'         ] if ( timesheet.committed )
      return [ 'edit', 'show' ]
    else
      return []
    end
  end

end
