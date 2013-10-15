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

  # The exceptions on 'confirm_permission' are matched by equal exceptions
  # in SavedReportsController, which defines those methods for in place
  # editing and verifies permissions before continuing. This is necessary
  # to avoid a great deal of mucking around trying to get Resourceful URLs
  # down into the in-place editor so it quotes the user ID in AJAX calls.
  # "Current user" is instead assumed here.

  before_filter :assign_user
  before_filter :confirm_permission,         :except => [ :set_saved_report_title, :set_saved_report_shared ]
  before_filter :delete_unnamed_reports_for, :only   => [ :index, :new, :create ]

private

  # All of this controller's actions are routed within the User resource, so
  # all requests must have a user ID.
  #
  def assign_user
    @user = User.find_by_id( params[ :user_id ] )
  end

  # If no user ID is present, or the requested user doesn't match the logged
  # in user, except for admins, then refuse access. Users should only ever be
  # doing stuff under their own user ID unless they are administrators.
  #
  def confirm_permission
    return appctrl_not_permitted() if ( @user.nil? || ! ( @current_user.admin? || @user == @current_user ) )
  end

  # Get rid of any unnamed reports for the current user. Usually invoked via
  # "before_filter(...)".
  #
  def delete_unnamed_reports_for
    SavedReport.where( :user_id => @current_user, :title => "" ).delete_all()
  end
end
