########################################################################
# File::    reports_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Generate reports describing timesheet entries in various
#           different ways. The ReportsController deals with finding
#           SavedReport model instances and, using the
#           TrackRecordReport::Report class with its attributes
#           configured from the SavedReport instance's contents,
#           generating and showing reports to users.
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

      @saved_report       = SavedReport.new( report_params() )
      @saved_report.user  = @current_user
      @saved_report.title = ''

      begin
        @saved_report.save!()
        redirect_to( report_path( @saved_report ) )

      rescue
        flash[ 'error' ] = "The legacy report could not be generated. An unknown error occurred."
        redirect_to( home_path() )
      end

      # NOTE EARLY EXIT!

      return

    elsif ( @saved_report.nil? || ! @saved_report.is_permitted_for?( @current_user ) )

      flash[ 'error' ] = @@application_helper.apphelp_view_hint(
        :not_found_error,
        ReportsController
      )

      redirect_to( home_path() ) and return

    end

    # Generate a compilable report from the saved parameters and compile
    # the report data into an easily understood form for report generators.
    #
    # By this point security checks have verified that the current user is
    # allowed to see the report, but they may be restricted and this might
    # not be their report in the first place. Thus we pass in the current
    # user to let the report mechanism below that filter tasks etc. as
    # required by the user's restrictions, if any.

    @report = @saved_report.generate_report( true, @current_user )
    @report.compile()

    if ( @saved_report.title.empty? )
      flash[ 'warning' ] = @@application_helper.apphelp_view_hint(
        :unnamed_warning,
        ReportsController
      )
    end

    if ( @report.throttled )
      flash[ 'error' ] = @@application_helper.apphelp_view_hint(
        :throttle_warning,
        ReportsController,
        {
          :original => @@application_helper.apphelp_date( @report.throttled ),
          :actual   => @@application_helper.apphelp_date( @report.range.min )
        }
      )
    end

    # Everything's ready to render the report in @report, but should we
    # actually be running a generator instead?

    if ( params.has_key?( :generator ) )

      # Generate a report via a plugin generator. Need to figure out which
      # one to use and get its parameters sent over.

      supported_types = [ :task, :user, :comprehensive ]

      TrackRecordReportGenerator.submodules.each do | submodule |

        self.extend( submodule )

        params_key = submodule.name.underscore

        if ( params.has_key?( params_key ) )
          generator_params = params[ params_key ]
          report_type      = supported_types.select do | supported_type |
            generator_params.has_key?( supported_type )
          end.first

          if ( understands?( report_type ) )
            generator_params.delete( report_type )
            result = generate( report_type, @report, generator_params )

            unless ( result.nil? )
              flash[ 'error' ] = result.to_s
              render( { :template => 'reports/show' } )
            end

            break
          end
        end
      end

    else

      # Simple render.

      render( { :template => 'reports/show' } )

    end

    flash.delete( 'warning' ) # Else these show on the *next* fetched page too
    flash.delete( 'error'   )
  end

private

  # Rails 4+ Strong Parameters, replacing in-model "attr_accessible".
  #
  def report_params
    appctrl_saved_report_params( :report )
  end

end
