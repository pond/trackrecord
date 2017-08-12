########################################################################
# File::    control_panels_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage User settings through a ControlPanel object.
# ----------------------------------------------------------------------
#           19-Jan-2008 (ADH): Created.
########################################################################

class ControlPanelsController < ApplicationController

  # Security. No direct CRUD actions are allowed at all. Everything
  # is done through user account editing.

  before_action( :appctrl_not_permitted )

end
