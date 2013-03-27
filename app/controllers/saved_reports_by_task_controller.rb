########################################################################
# File::    saved_reports_by_task_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Generate 'canned' reports for a specific task.
# ----------------------------------------------------------------------
#           23-Mar-2013 (ADH): Created.
########################################################################

class SavedReportsByTaskController < SavedReportsBaseController

  # Generate a report based on a 'new report' form submission.
  #
  def create
    task = Task.find( params[ :item ] )

    saved_report                       = SavedReport.new()
    saved_report.user                  = @user
    saved_report.title                 = ""
    saved_report.shared                = false

    saved_report.frequency             = "5" # Weekly

    saved_report.include_committed     = true
    saved_report.include_not_committed = true

    if ( task.active? )
      saved_report.active_task_ids = [ task.id ]
    else
      saved_report.inactive_task_ids = [ task.id ]
    end

    if ( saved_report.save )
      redirect_to( report_path( saved_report ) )
    else
      redirect_to( home_path() )
    end
  end
end
