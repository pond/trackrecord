########################################################################
# File::    work_packets_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage WorkPacket objects. See models/work_packet.rb for
#           more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

class WorkPacketsController < ApplicationController

  # Security. No direct CRUD actions are allowed at all. Everything
  # is done through timesheet editing.

  before_filter( :appctrl_not_permitted )

end
