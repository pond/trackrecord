########################################################################
# File::    saved_reports_by_customer_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Generate 'canned' reports for a specific customer.
# ----------------------------------------------------------------------
#           23-Mar-2013 (ADH): Created.
########################################################################

class SavedReportsByCustomerController < SavedReportsBaseController

  # Generate a report based on a 'new report' form submission.
  #
  def create
    customer = Customer.find( params[ :item ] )

    saved_report                       = SavedReport.new()
    saved_report.user                  = @user
    saved_report.title                 = ""
    saved_report.shared                = false

    saved_report.frequency             = "5" # Weekly

    saved_report.include_committed     = true
    saved_report.include_not_committed = false

    saved_report.active_task_ids       = customer.tasks.where( :active => true  ).map( & :id )
    saved_report.inactive_task_ids     = customer.tasks.where( :active => false ).map( & :id )
    saved_report.task_grouping         = "both"

    if ( saved_report.active_task_ids.count.zero? && saved_report.inactive_task_ids.count.zero? )
      flash[ 'error' ] = 'The customer has no associated tasks to show in a report.'
      redirect_to( home_path() )
    elsif ( saved_report.save )
      redirect_to( report_path( saved_report ) )
    else
      redirect_to( home_path() )
    end
  end
end
