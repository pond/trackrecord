########################################################################
# File::    saved_reports_copy_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Provide a RESTful mechanism for copying a saved report,
#           presenting the copy as an editable new unsaved item.
# ----------------------------------------------------------------------
#           31-Jul-2013 (ADH): Created.
########################################################################

class SavedReportsCopyController < SavedReportsBaseController
  def new
    @saved_report      = SavedReport.new
    @saved_report.user = @user
    @user_array        = @current_user.restricted? ? [ @current_user ] : User.active
  end
end
