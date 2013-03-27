########################################################################
# File::    task_group.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Base class for things which group tasks, such as Projects
#           or Customers. See below for more details.
# ----------------------------------------------------------------------
#           07-Mar-2008 (ADH): Created from project.rb.
########################################################################

class TaskGroup < ActiveRecord::Base

  self.abstract_class = true

  # Define default sort order for caller convenience.

  DEFAULT_SORT_COLUMN    = 'title'
  DEFAULT_SORT_DIRECTION = 'ASC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

  default_scope( { :order => DEFAULT_SORT_ORDER } )

  named_scope( :active,   :conditions => { :active => true  } )
  named_scope( :inactive, :conditions => { :active => false } )

  # Derived classes must state their associations. None are set up
  # in the base class. They should also restrict mass assignment to
  # attributes (attr_protected or attr_accessible) and set up any
  # required acts_as_audited settings.

  # Make sure the data is sane.

  validates_presence_of( :title )
  validates_uniqueness_of( :title )

  validates_inclusion_of(
    :active,
    :in => [ true, false ],
    :message => "must be set to 'True' or 'False'"
  )

  # Return the object's title. This is done for loose compatibility
  # with a Task object during report generation.
  #
  def augmented_title
    return self.title
  end

  # Find all projects which the given user is allowed to see.
  # A conditions hash may be passed to further restrict the search
  # (that is, the "{...}" in "find( :all, :conditions => {...})").
  #
  def self.find_permitted( user, conditions = nil )

    # Can't see any items if no user is given. Can see all items if
    # the user is unrestricted.

    return [] unless user

    items = find( :all, { :conditions => conditions } )
    return items if user.privileged?

    allowed = []

    items.each do | item |
      allowed.push( item ) if item.is_permitted_for?( user )
    end

    return allowed
  end

  # Is the given user permitted to update this object? Restricted users
  # cannot modify things. Administrators always can. Managers only can
  # if the object is still active.
  #
  def can_be_modified_by?( user )
    return false if ( user.restricted? )
    return true  if ( user.admin?      )
    return self.active
  end

  # Is permission granted for the given user to see this project?
  # See also find_permitted. Returns 'true' if permitted, else 'false'.
  #
  def is_permitted_for?( user )
    return true if user.privileged?

    # User is restricted. User can only see this project if it
    # has at least one task associated with it and at least one
    # of those associated tasks appears in the user's permitted
    # task list, so check the intersection of the two arrays.

    return false if ( self.tasks.empty? )
    return true  if ( self.tasks & user.tasks ).length > 0

    # None of the project's tasks are in the user's permitted
    # list, so the user is not permitted to see this project.

    return false
  end
end
