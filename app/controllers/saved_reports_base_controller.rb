########################################################################
# File::    saved_reports_base_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Underlying controller used for shared code common to other
#           saved-report-related activities.
# ----------------------------------------------------------------------
#           23-Mar-2013 (ADH): Created.
########################################################################

class SavedReportsBaseController < ApplicationController

  before_filter :confirm_permission
  before_filter :delete_unnamed_reports_for, :only => [ :index, :new, :create ]

private

  # All of this controller's actions are routed within the User resource, so
  # all requests must have a user ID. 

  def confirm_permission
    @user = User.find_by_id( params[ :user_id ] )
    return appctrl_not_permitted() if ( @user.nil? || ! ( @user.admin? || @user == @current_user ) )
  end

  # Get rid of any unnamed reports for the current user. Usually invoked via
  # "before_filter(...)".
  #
  def delete_unnamed_reports_for
    SavedReport.where( :user_id => @current_user, :title => "" ).delete_all()
  end
end
