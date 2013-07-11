########################################################################
# File::    reports_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Generate reports describing timesheet entries in various
#           different ways. The ReportsController deals with finding
#           SavedReport model instances and, using TrackRecordReport's
#           Report class with its attributes configured from the
#           SavedReport instance's contents, generating and showing
#           reports to users.
# ----------------------------------------------------------------------
#           09-Feb-2008 (ADH): Created.
#           19-Oct-2011 (ADH): Functionality split up into this file and
#                              SavedReportsController.
########################################################################

class ReportsController < ApplicationController

  require 'csv'

  include TrackRecordReport
  include TrackRecordSections

  # Import the Application Helper methods into an object stored in a class
  # variable.

  @@application_helper = Object.new.extend( ApplicationHelper )

  # Retrieve saved report parameters from the database and generate a report
  # using those parameters, restricted by whatever prevailing permissions may
  # apply to the current user.
  #
  def show
    @saved_report = SavedReport.find_by_id( params[ :id ] )

    # Legacy report link, or missing / unauthorized report?

    if ( @saved_report.nil? && params.has_key?( :report ) )

      # This is pretty weird as active tasks at the time the link to the
      # legacy report was generated may have become inactive or vice versa.
      # Indeed even with a conventionally generated report, another user of
      # the system may have changed an included task's active flag.
      #
      # This means that the report's active_tasks and inactive_tasks lists
      # may contain a mixture of active and inactive items. Fortunately,
      # this is all resolved by the TrackRecordReport code when the IDs are
      # given to the Report instance. It re-finds and re-builds the list of
      # tasks, assigning them to the correct active/inactive lists as it
      # does so.
      #
      # Really the active-vs-inactive list stuff inside a SavedReport is a
      # legacy throwback to the old directly generated non-model report
      # code in TrackRecord v1.x - nothing more.

      params[ :report ][ :reportable_user_ids ] = params[ :report ].delete( :user_ids )

      @saved_report       = SavedReport.new( params[ :report ] )
      @saved_report.user  = @current_user
      @saved_report.title = ''

      begin
        @saved_report.save!()
        redirect_to( report_path( @saved_report ) )

      rescue
        flash[ :error ] = "The legacy report could not be generated. An unknown error occurred."
        redirect_to( home_path() )
      end

      # NOTE EARLY EXIT!

      return

    elsif ( @saved_report.nil? || ( @saved_report.user_id != @current_user.id && ! @saved_report.shared && ! @current_user.admin? ) )

      flash[ :error ] = "The requested report was not found; the owner may have deleted it."
      redirect_to( home_path() ) and return

    end

    # Read parameters related to the 'show' action, which itself contains a
    # form that submits back to here  fincluding details about CSV export
    # parameters. For plain old "show report <id>" uses, there are no such
    # additional parameters.

    read_options()

    @report = @saved_report.generate_report()
    @report.compile()

    if ( @saved_report.title.empty? )
      flash[ :warning ] = "This report is unnamed. It will be deleted automatically. To save it permanently, use the 'Change report parameters' link underneath the report and give it a name."
    end

    respond_to do | format |
      format.html { render( { :template => 'reports/show' } ) }
      format.csv  { csv_stream_report() }
    end

    flash.delete( :warning ) # Else it shows on the *next* fetched page too
  end

private

  # Read transient options from a report-related form submission. On exit,
  # the following variables are set:
  #
  #   Name            Meaning
  #   =========================================================================
  #   @is_task_type   If 'true' a CSV format report should provide a task-based
  #                   breakdown of time, else a user-based breakdown. Undefined
  #                   for non-CSV reports.
  #
  #   @exclude_title  If 'true' a title row should be excluded in a CSV format
  #                   report. Undefined for non-CSV reports.
  #
  def read_options
    if ( request.format.csv? )
      @is_task_type  = params[ :user_report ].nil?
      type           = @is_task_type ? 'task' : 'user'
      @exclude_title = ! ( params[ "include_title_#{ type }" ] == '1' )
    end
  end

  # Send a report to the browser in CSV format. Requires "@report" to contain
  # a calculated report. Examines the params hash to see if additional data is
  # present which might influence the output (e.g. things to exclude, type of
  # report to send).
  #
  def csv_stream_report()
    headings = []
    headings << ' (total)'    if ( @report.include_totals        )
    headings << ' (com.)'     if ( @report.include_committed     )
    headings << ' (not com.)' if ( @report.include_not_committed )

    @is_task_type = params[ :user_report ].nil?

    # Old-style streaming has becomes unreliable lately; the v1.0 approach as
    # per "http://oldwiki.rubyonrails.org/rails/pages/HowtoExportDataAsCSV"
    # often failed with Rails 2.3 and/or certain FasterCSV versions (I never
    # did find out exactly what caused the problem though).
    #
    # The simplest solution is to use the ActiveRecord::Streaming "send_data"
    # call, putting all the load on the Rails framework. Unfortunately this
    # means the whole CSV file ends up in RAM before being sent - inefficient.

    label     = @report.label.downcase.gsub( ' ', '_' )
    sformat   = '%Y%m%d'   # Compressed ISO-style
    fformat   = '%Y-%m-%d' # Less compressed ISO-style
    stoday    = Date.current.strftime( sformat )
    ftoday    = Date.current.strftime( fformat )
    sstart_at = @report.range.first.strftime( sformat )
    fstart_at = @report.range.first.strftime( fformat )
    send_at   = @report.range.last.strftime( sformat )
    fend_at   = @report.range.last.strftime( fformat )
    filename  = "report_#{ label }_on_#{ stoday }_for_#{ sstart_at }_to_#{ send_at }.csv"
    title     = [
      "#{ @is_task_type ? 'Task' : 'User' } report on #{ ftoday }",
      "From #{ fstart_at }",
      "To #{ fend_at }",
      '(inclusive)'
    ]

    # First compile the file.

    whole_csv_file = CSV.generate do | csv |
      unless ( @exclude_title )
        csv << [ @report.title ] unless @report.title.empty?
        csv << title
      end

      if ( @is_task_type )
        csv_report_by_task( csv, headings )
      else
        csv_report_by_user( csv, headings )
      end
    end

    # Next send the data all in one go.

    send_data(
      whole_csv_file,
      {
        :type        => 'text/csv',
        :disposition => 'attachment',
        :filename    => filename
      }
    )
  end

  # Send a by-task CSV format report through the given CSV output stream. Pass
  # also a headings array that gives the heading suffices for each of the kinds
  # of numbers that "hours" will output based on prevailing instance variables
  # (see that function for details).
  #
  def csv_report_by_task( csv, headings )
    # Assemble the heading row.

    file_row = [ @report.column_title, 'Code', 'Billable?', 'Active?' ]

    @report.column_ranges.each_index do | col_index |
      partial = @report.partial_column?( col_index ) ? ' (partial)' : ''
      headings.each do | heading |
        file_row << "#{ @report.column_heading( col_index ) }#{ partial }#{ heading }"
      end
    end

    headings.each do | heading |
      file_row << "Row total#{ heading }"
    end

    if ( @report.filtered_users.empty? )
      file_row << 'Duration'
      file_row << 'Remaining (actual)'
      file_row << 'Remaining (potential)'
    end

    csv << file_row.flatten

    # Section and task list, date range breakdown.

    sections_initialise_sections()
    @report.rows.each_index do | row_index |

      row      = @report.rows[ row_index ]
      task     = @report.filtered_tasks[ row_index ]
      file_row = []

      # New section? Write out the section title and totals if so.

      if ( sections_new_section?( task ) )
        file_row << sections_section_title( true )
        file_row << ( task.project.try( :code ) || '-' ) << '' << ''

        row.cells.each_index do | col_index |
          file_row << hours( @report.sections[ sections_section_index() ].cells[ col_index ] )
        end

        file_row << hours( @report.sections[ sections_section_index() ] )

        if ( @report.filtered_users.empty? )
          file_row << '' << '' << ''
        end

        csv << file_row.flatten
        file_row = []
      end

      # Task title, data and summary information

      file_row << " -- #{ task.title }"
      file_row << task.code
      file_row << @@application_helper.apphelp_boolean( task.billable )
      file_row << @@application_helper.apphelp_boolean( task.active   )

      row.cells.each do | cell |
        file_row << hours( cell )
      end

      file_row << hours( row )

      if ( @report.filtered_users.empty? )
        if ( task.duration == 0.0 )
          file_row << '' << '' << ''
        else
          file_row << task.duration
          file_row << task.duration - row.committed
          file_row << task.duration - row.total
        end
      end

      csv << file_row.flatten
    end

    # Column totals.

    file_row = [ 'Column total', '', '', '' ]

    @report.column_totals.each do | total |
      file_row << hours( total )
    end

    file_row << hours( @report )

    if ( @report.filtered_users.empty? )
      file_row << @report.total_duration
      file_row << @report.total_actual_remaining
      file_row << @report.total_potential_remaining
    end

    csv << file_row.flatten
  end

  # As "csv_report_by_task", but generates a per-user report.

  def csv_report_by_user( csv, headings )

    # Assemble the heading row.

    file_row = [ '', 'Code', 'Billable?', 'Active?' ]

    @report.filtered_users.each do | user |
      headings.each do | heading |
        file_row << "#{ user.name }#{ heading }"
      end
    end

    headings.each do | heading |
      file_row << "Row total#{ heading }"
    end

    csv << file_row.flatten

    # Section and task list, user breakdown.

    sections_initialise_sections()
    @report.rows.each_index do | row_index |

      row      = @report.rows[ row_index ]
      task     = @report.filtered_tasks[ row_index ]
      file_row = []

      # New section? Write out the section title and totals if so.

      if ( sections_new_section?( task ) )
        file_row << sections_section_title( true )
        file_row << ( task.project.try( :code ) || '-' ) << '' << ''

        @report.filtered_users.each_index do | user_index |
          file_row << hours( @report.sections[ sections_section_index() ].user_row_totals[ user_index ] )
        end

        file_row << hours( @report.sections[ sections_section_index() ] )

        csv << file_row.flatten
        file_row = []
      end

      # Task title, data and summary information

      file_row << " -- #{ task.title }"
      file_row << task.code
      file_row << @@application_helper.apphelp_boolean( task.billable )
      file_row << @@application_helper.apphelp_boolean( task.active   )

      row.user_row_totals.each do | user_row_total |
        file_row << hours( user_row_total )
      end

      file_row << hours( row )
      csv << file_row.flatten
    end

    # Column totals.

    file_row = [ 'Column total', '', '', '' ]

    @report.user_column_totals.each do | user_column_total |
      file_row << hours( user_column_total )
    end

    file_row << hours( @report )
    csv << file_row.flatten
  end

  # Return an array with total, committed and not committed hours based
  # on the given TrackRecordReport::ReportElementaryCalculator object.
  # Items will be excluded according to the report's "include_*" options.
  #
  def hours( calculator )
    a = []
    a << terse_hours( calculator.total         ) if ( @report.include_totals         )
    a << terse_hours( calculator.committed     ) if ( @report.include_committed      )
    a << terse_hours( calculator.not_committed ) if ( @report.include_not_committed  )
    return a
  end

  # Terse hours - return a given float number of hours to 2d.p. or the
  # smallest possible form (e.g. "0.0" becomes "0").
  #
  def terse_hours( hours )
    return hours.precision( 2 ).to_s.chomp( '0' ).chomp( '0' ).chomp( '.' )
  end
end
