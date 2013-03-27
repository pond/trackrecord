########################################################################
# File::    saved_reports_by_user_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Generate 'canned' reports for a specific user.
# ----------------------------------------------------------------------
#           23-Mar-2013 (ADH): Created.
########################################################################

class SavedReportsByUserController < SavedReportsBaseController

  # Generate a report based on a 'new report' form submission.
  #
  def create
    of_user = User.find( params[ :item ] )

    saved_report                       = SavedReport.new()
    saved_report.user                  = @user
    saved_report.title                 = ""
    saved_report.shared                = false
    saved_report.frequency             = "5" # Weekly

    saved_report.include_committed     = true
    saved_report.include_not_committed = true
    saved_report.exclude_zero_rows     = true
    saved_report.exclude_zero_cols     = true

    saved_report.reportable_users      = [ of_user ]

    saved_report.task_grouping         = "both"

    if ( saved_report.save )
      redirect_to( report_path( saved_report ) )
    else
      redirect_to( home_path() )
    end
  end
end
