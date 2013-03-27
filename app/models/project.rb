########################################################################
# File::    project.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Describe the behaviour of Project objects. See below for
#           more details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class Project < TaskGroup

  acts_as_audited( :except => [
    :lock_version,
    :updated_at,
    :created_at,
    :id,
    :code,
    :description
  ] )

  # A Project is an organisational unit for the benefit of the
  # timesheet system operator. Projects consist of a series of
  # tasks. The project's expected duration is the sum of the
  # expected durations of its tasks. ControlPanel objects refer
  # to Projects as the default project used in task creation.
  # Each project belongs to a single Customer.

  belongs_to( :customer )

  has_many( :tasks )
  has_many( :control_panels )

  named_scope( :unassigned, { :conditions => { :customer_id => nil } } )

  # Unfortunately, Acts As Audited runs on this model (see above) and
  # uses attr_protected. Rails doesn't allow both, so I have to use
  # the less-secure attr_protected here too.

  attr_protected(
    :customer_ids,
    :control_panel_ids
  )

  # Assign default conditions for a brand new object, used whether
  # or not the object ends up being saved in the database (so a
  # before_create filter is not sufficient). For user-specific
  # default values, pass a User object.
  #
  def assign_defaults( user )
    self.active = true
    self.code   = "PID%04d" % Project.count

    # User-specific defaults - pick up the default customer
    # from the user's control panel, if defined.

    if ( user and user.control_panel )
      cp = user.control_panel
      self.customer = cp.customer if ( cp.customer and cp.customer.active )
    end
  end

  # Update an object with the given attributes. This is done by a
  # special model method because changes of the 'active' flag have
  # side effects for other associated objects. THE CALLER **MUST**
  # USE A TRANSACTION around a call to this method. There is no
  # need to call here unless the 'active' flag state is changing.
  # Pass in 'true' to update associated tasks, else 'false'. If
  # omitted, defaults to 'true'.
  #
  def update_with_side_effects!( attrs, update_tasks = true )
    active = self.active
    self.update_attributes!( attrs )

    # If the active flag has changed, deal with repercussions.

    if ( update_tasks and attrs[ :active ] != active )
      self.tasks.each do | task |
        task.update_with_side_effects!( { :active => attrs[ :active ] } )
      end
    end
  end

  # As update_with_side_effects!, but destroys things rather than
  # updating them. Pass 'true' to destroy associated tasks, else
  # 'false'. If omitted, defaults to 'true'.
  #
  def destroy_with_side_effects( destroy_tasks = true )
    if ( destroy_tasks )
      self.tasks.each do | task |
        task.destroy()
      end
    end

    self.destroy()
  end
end
