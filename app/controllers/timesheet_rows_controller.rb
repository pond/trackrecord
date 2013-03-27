########################################################################
# File::    timesheet_rows_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage TimesheetRow objects. See models/timesheet_row.rb
#           for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

class TimesheetRowsController < ApplicationController

  # Security. No direct CRUD actions are allowed at all. Everything
  # is done through timesheet editing.

  before_filter( :appctrl_not_permitted )

end
