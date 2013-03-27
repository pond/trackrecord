########################################################################
# File::    control_panel.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Manage settings for individual User models. See below for
#           more details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class ControlPanel < ActiveRecord::Base

  # A ControlPanel object manages settings for a User. Among
  # other things, it allows a HABTM relationship with Tasks for
  # the default tasks shown in a Timesheet, while a User object
  # also maintains a HABTM relationship with Tasks for a list
  # of the tasks that the user is allowed to see.

  belongs_to( :user )
  has_and_belongs_to_many( :tasks )

  # Default customer and project to associate with a new task.

  belongs_to( :project  )
  belongs_to( :customer )

  # Security controls.

  attr_accessible(
    :task_ids,
    :project_id,
    :customer_id
  )

  # Remove inactive tasks from the control panel. The caller
  # is responsible for saving the updated object.
  #
  def remove_inactive_tasks
    # See the User model's remove_inactive_tasks method for details.

    self.tasks = Task.active & self.tasks
  end
end
