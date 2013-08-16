########################################################################
# File::    track_record_report_generator_uk_org_pond_csv.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Generate CSV format reports and send the data to browsers.
# ----------------------------------------------------------------------
#           25-Jul-2013 (ADH): Created.
########################################################################

module TrackRecordReportGenerator::UkOrgPondCSV

  require 'csv'

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def understands?( type )
    case type
      when :user, :task, :comprehensive
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
      when :user
        "Export user report in CSV format"
      when :task
        "Export task report in CSV format"
      when :comprehensive
        "Export comprehensive report in CSV format"
    end
  end

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def invocation_options_for( type )
    [
      {
        :checkbox =>
        {
          :label   => "Add title to first row",
          :checked => true,
          :id      => uk_org_pond_id_for_type( type )
        }
      }
    ]
  end

  # ====================================================================
  # See module TrackRecordReportGenerator for details.
  #
  def generate( report_type, report, options = {} )

    include_title = ( options[ uk_org_pond_id_for_type( report_type ) ] == '1' )

    headings = []
    headings << ' (total)'    if ( report.include_totals        )
    headings << ' (com.)'     if ( report.include_committed     )
    headings << ' (not com.)' if ( report.include_not_committed )

    # Old-style streaming has becomes unreliable lately; the v1.0 approach as
    # per "http://oldwiki.rubyonrails.org/rails/pages/HowtoExportDataAsCSV"
    # often failed with Rails 2.3 and/or certain FasterCSV versions (I never
    # did find out exactly what caused the problem though).
    #
    # The simplest solution is to use the ActiveRecord::Streaming "send_data"
    # call, putting all the load on the Rails framework. Unfortunately this
    # means the whole CSV file ends up in RAM before being sent - inefficient.

    label     = report.label.downcase.gsub( ' ', '_' )
    sformat   = '%Y%m%d'   # Compressed ISO-style
    fformat   = '%Y-%m-%d' # Less compressed ISO-style
    stoday    = Date.current.strftime( sformat )
    ftoday    = Date.current.strftime( fformat )
    sstart_at = report.range.min.strftime( sformat )
    fstart_at = report.range.min.strftime( fformat )
    send_at   = report.range.max.strftime( sformat )
    fend_at   = report.range.max.strftime( fformat )
    filename  = "report_#{ label }_on_#{ stoday }_for_#{ sstart_at }_to_#{ send_at }.csv"
    title     = [
      "#{ report_type.to_s.capitalize } report on #{ ftoday }",
      "From #{ fstart_at }",
      "To #{ fend_at }",
      '(inclusive)'
    ]

    # First compile the file.

    whole_csv_file = CSV.generate do | csv |
      if ( include_title )
        csv << [ report.title ] unless report.title.empty?
        csv << title
      end

      case report_type
        when :user
          uk_org_pond_csv_report_by_user( csv, report, headings )
        when :comprehensive
          uk_org_pond_csv_report_by_task( csv, report, headings, true )
        else
          uk_org_pond_csv_report_by_task( csv, report, headings, false )
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

      # Send a by-task CSV format report through the given CSV output stream using
      # the given TrackRecordReport::Report instance. Pass also a headings array that
      # gives the heading suffices for each of the kinds of numbers that "hours" will
      # output based on prevailing instance variables (see that function for details).
      # The last parameter is a "comprehensive report" flag, forcing per-user
      # breakdown on the assumption that a report is appropriate compiled.
      #
      def uk_org_pond_csv_report_by_task( csv, report, headings, comprehensive )
        # Assemble the heading row.

        file_row = [ report.column_title, 'Code', 'Billable?', 'Active?' ]

        report.each_column_range do | range |
          partial = report.partial_column?( range ) ? ' (partial)' : ''
          headings.each do | heading |
            file_row << "#{ report.column_heading( range, true ) }#{ partial }#{ heading }"
          end
        end

        headings.each do | heading |
          file_row << "Row total#{ heading }"
        end

        if ( report.filtered_users.empty? )
          file_row << 'Duration'
          file_row << 'Remaining (actual)'
          file_row << 'Remaining (potential)'
        end

        csv << file_row.flatten

        # Section and task list, date range breakdown.

        application_helper = Object.new.extend( ApplicationHelper )

        report.each_row do | row, task |

          section, is_new_section, group, is_new_group = @report.retrieve( task.id.to_s )
          file_row = []

          # New section? Write out the section title and totals if so.

          if ( is_new_section )
            file_row << section.title( nil, true )
            file_row << ( task.project.try( :code ) || '-' ) << '' << ''

            report.each_cell_for( section ) do | section_cell |
              file_row << uk_org_pond_hours( report, section_cell )
            end

            file_row << uk_org_pond_hours( report, section )

            if ( report.filtered_users.empty? )
              file_row << '' << '' << ''
            end

            csv << file_row.flatten
            file_row = []
          end

          # Task title, data and summary information

          file_row << " -- #{ task.title }"
          file_row << task.code
          file_row << application_helper.apphelp_boolean( task.billable )
          file_row << application_helper.apphelp_boolean( task.active   )

          report.each_cell_for( row ) do | cell |
            file_row << uk_org_pond_hours( report, cell )
          end

          file_row << uk_org_pond_hours( report, row )

          if ( report.filtered_users.empty? )
            if ( task.duration == 0.0 )
              file_row << '' << '' << ''
            else
              file_row << task.duration
              file_row << task.duration - ( row.try( :committed ) || 0 )
              file_row << task.duration - ( row.try( :total     ) || 0 )
            end
          end

          csv << file_row.flatten

          if ( comprehensive )
            report.each_user_on_row( row ) do | user, row_total_for_user |

              file_row = [ " ---- #{ user.name }", '', '', '' ]

              report.each_cell_for_user_on_row( user, row ) do | cell_for_user |
                file_row << uk_org_pond_hours( report, cell_for_user )
              end

              file_row << uk_org_pond_hours( report, row_total_for_user )
            end

            csv << file_row.flatten
          end
        end

        # Column totals.

        file_row = [ 'Column total', '', '', '' ]

        report.each_column_total do | total |
          file_row << uk_org_pond_hours( report, total )
        end

        file_row << uk_org_pond_hours( report, report )

        if ( report.filtered_users.empty? )
          file_row << report.total_duration
          file_row << report.total_actual_remaining
          file_row << report.total_potential_remaining
        end

        csv << file_row.flatten
      end

      # As "uk_org_pond_csv_report_by_task", but generates a per-user report.

      def uk_org_pond_csv_report_by_user( csv, report, headings )

        # Assemble the heading row.

        file_row = [ '', 'Code', 'Billable?', 'Active?' ]

        report.each_user do | user |
          headings.each do | heading |
            file_row << "#{ user.name }#{ heading }"
          end
        end

        headings.each do | heading |
          file_row << "Row total#{ heading }"
        end

        csv << file_row.flatten

        # Section and task list, user breakdown.

        application_helper = Object.new.extend( ApplicationHelper )

        report.each_row do | row, task |

          section, is_new_section, group, is_new_group = @report.retrieve( task.id.to_s )
          file_row = []

          # New section? Write out the section title and totals if so.

          if ( is_new_section )
            file_row << section.title( nil, true )
            file_row << ( task.project.try( :code ) || '-' ) << '' << ''

            report.each_user do | user |
              file_row << uk_org_pond_hours( report, section.try( :user_total, user.id.to_s ) )
            end

            file_row << uk_org_pond_hours( report, section )

            csv << file_row.flatten
            file_row = []
          end

          # Task title, data and summary information

          file_row << " -- #{ task.title }"
          file_row << task.code
          file_row << application_helper.apphelp_boolean( task.billable )
          file_row << application_helper.apphelp_boolean( task.active   )

          report.each_user do | user |
            file_row << uk_org_pond_hours( report, row.try( :user_total, user.id.to_s ) )
          end

          file_row << uk_org_pond_hours( report, row )
          csv << file_row.flatten
        end

        # Column totals.

        file_row = [ 'Column total', '', '', '' ]

        report.each_user do | user |
          file_row << uk_org_pond_hours( report, report.try( :user_total, user.id.to_s ) )
        end

        file_row << uk_org_pond_hours( report, report )
        csv << file_row.flatten
      end

      # Return an array with total, committed and not committed hours based
      # on the given TrackRecordReport::Report instance's configuration and a
      # TrackRecordReport::ReportElementaryCalculator object.
      #
      def uk_org_pond_hours( report, calculator )
        a = []
        a << uk_org_pond_terse_hours( calculator.try( :total         ) || 0 ) if ( report.include_totals         )
        a << uk_org_pond_terse_hours( calculator.try( :committed     ) || 0 ) if ( report.include_committed      )
        a << uk_org_pond_terse_hours( calculator.try( :not_committed ) || 0 ) if ( report.include_not_committed  )
        return a
      end

      # Terse hours - return a given float number of hours to 2d.p. or the
      # smallest possible form (e.g. "0.0" becomes "0").
      #
      def uk_org_pond_terse_hours( hours )
        return hours.precision( 2 ).to_s.chomp( '0' ).chomp( '0' ).chomp( '.' )
      end

      # Return a form element ID to use for a given report type.
      #
      def uk_org_pond_id_for_type( type )
        "include_title_for_#{ type }"
      end

    end # class << base
  end   # def self.extended( base )
end     # module TrackRecordReportGenerator::UkOrgPondCSV
