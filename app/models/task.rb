########################################################################
# File::    task.rb
# (C)::     Hipposoft 2007
#
# Purpose:: Describe the behaviour of Task objects. See below for more
#           details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class Task < Rangeable

  audited( :except => [
    :lock_version,
    :updated_at,
    :created_at,
    :id
  ] )

  DEFAULT_SORT_COLUMN    = 'title'
  DEFAULT_SORT_DIRECTION = 'ASC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

  USED_RANGE_COLUMN      = 'created_at' # For Rangeable base class

  # Set a default order; note also the default eager-loading scope
  # added later.

  default_scope( { :order => DEFAULT_SORT_ORDER } )

  scope( :active,     :conditions => { :active     => true  } )
  scope( :inactive,   :conditions => { :active     => false } )
  scope( :unassigned, :conditions => { :project_id => nil   } )

  # Tasks are the fundamental building blocks of a Project. They define
  # specific pieces of work of expected duration, against which work
  # packets are carried out. A WorkPacket object describes an amount of
  # time worked against the project by any User. WorkPacket objects are
  # held within TimesheetRow objects, each related to a specific task.
  #
  # Every Task has an expected duration stored as a number of hours. It
  # is exceptionally common for a task's project and customer (if any)
  # to be looked up, so eager loading those at all times ends up saving
  # on database overhead on average. The default scope set here will
  # combine with the order-related scope set earlier.

  belongs_to( :project )

  default_scope( includes( { :project => :customer } ) )

  has_many( :timesheet_rows, { :dependent => :destroy        } )
  has_many( :work_packets,   { :through   => :timesheet_rows } )

  # A Task has and belongs to many ControlPanel objects as a way of
  # setting up the list of Tasks shown in a timesheet editing view when
  # the User is filling in their timesheet. A Task has many User objects
  # for restricted user types; they can only view those specific tasks.

  has_and_belongs_to_many( :control_panels )
  has_and_belongs_to_many( :users          )

  attr_protected(
    :timesheet_row_ids,
    :work_packet_ids,
    :control_panel_ids,
    :user_ids
  )

  # Make sure the data is sane.

  validates_presence_of( :title, :duration )
  validates_numericality_of( :duration, :greater_than_or_equal_to => 0 )

  validates_inclusion_of(
    :active,
    :in => [ true, false ],
    :message => "must be set to 'True' or 'False'"
  )

  validate( :project_is_active )

  # Some default properties are dynamic, so assign these here rather than
  # as defaults in a migration.
  #
  # Parameters:
  #
  #   Optional hash used for instance initialisation in the traditional way
  #   for an ActiveRecord subclass.
  #
  #   Optional User object. A default project is taken from that user's
  #   control panel data, if available.
  #
  #
  def initialize( params = nil, user = nil )
    super( params )

    if ( params.nil? )
      self.duration = 0
      self.active   = true
      self.code     = "TID%05d" % Task.count

      if ( user and user.control_panel )
        cp = user.control_panel
        self.project = cp.project if ( cp.project and cp.project.active )
      end
    end
  end

  # Is the given user permitted to do anything with this task?
  #
  def is_permitted_for?( user )
    return ( user.privileged? or user.tasks.include?( self ) )
  end

  # Is the given user permitted to update this task? Restricted users
  # cannot modify tasks. Administrators always can. Managers only can
  # if the task is still active.

  def can_be_modified_by?( user )
    return false if ( user.restricted? )
    return true  if ( user.admin?      )
    return self.active
  end

  # Given an ID, generate a task code for an XML-imported task based on the
  # current date.
  #
  def self.generate_xml_code( id )
    today = Date.current
    "XML-%04d%02d%02d-#{ id }" % [ today.year, today.month, today.day ]
  end

  # Return the 'augmented' task title; that is, the task name, with
  # the project and customer names appended if available.
  #
  def augmented_title
    if ( self.project )
      if ( self.project.customer )
        return "#{ self.project.customer.title } - #{ self.project.title }: #{ self.title }"
      end

      return "#{ self.project.title }: #{ self.title }"
    end

    return "#{ self.title }"
  end

  # Class method - sort an array of tasks by the augmented title.
  # Since this isn't done by the database, it's slow.
  #
  def self.sort_by_augmented_title( list )
    list.sort! { | x, y | x.augmented_title <=> y.augmented_title }
  end

  # Return an array with two elements - the first is the restricted
  # associated users, the second the unrestricted associated users.
  # Arrays will be empty if there are no associated users. Does this
  # the slow way, asking each user if it is restricted, rather than
  # making assumptions about how to quickly find restricted types.
  #
  def split_user_types
    restricted   = []
    unrestricted = []

    self.users.all.each do | user |
      if ( user.restricted? )
        restricted.push( user )
      else
        unrestricted.push( user )
      end
    end

    return [ restricted, unrestricted ]
  end

  # Update an object with the given attributes. This is done by a
  # special model method because changes of the 'active' flag have
  # side effects for other associated objects. THE CALLER **MUST**
  # USE A TRANSACTION around a call to this method. There is no
  # need to call here unless the 'active' flag state is changing.
  #
  def update_with_side_effects!( attrs )
    active = self.active
    self.update_attributes!( attrs )

    # If the active flag has changed and it *was* 'true', then the task
    # has just been made inactive.

    if ( attrs[ :active ] != active and active == true )

      # When tasks are made inactive, remove them from each of the Task lists
      # in User and ControlPanel objects. There are checks for this elsewhere,
      # but they're only to try and catch cases where this code has gone wrong.
      #
      # Although only restricted users make use of this list, other user types
      # may have a list set up either accidentally or because the user's type
      # is due to be changed to one with lower permissions. As a result, we
      # must update every user.

      User.all.each do | user |
        user.remove_inactive_tasks()
        user.save!
      end

      ControlPanel.all.each do | cp |
        cp.remove_inactive_tasks()
        cp.save!
      end
    end
  end

  # Number of hours worked on this task, committed or otherwise
  #
  def total_worked
    return self.work_packets.sum( :worked_hours ) || 0.0
  end

  # Number of committed hours worked on this task.
  #
  def committed_worked
    sum = 0.0

    self.work_packets.all.each do | work_packet |
      sum += work_packet.worked_hours if ( work_packet.timesheet_row.timesheet.committed )
    end

    return sum
  end

  # Number of not committed hours worked on this task.
  #
  def not_committed_worked
    sum = 0.0

    self.work_packets.all.each do | work_packet |
      sum += work_packet.worked_hours unless ( work_packet.timesheet_row.timesheet.committed )
    end

    return sum
  end

  # Number of hours worked on the task between the given start
  # and end Dates as a Range. Optionally pass a User object; work
  # packets will only be counted if they're in a timesheet
  # belonging to that user.
  #
  # Returns an object with fields 'committed' and 'not_committed',
  # giving sums for those types of hours.
  #
  def sum_hours_over_range( date_range, user = nil )
    committed_sum     = 0.0
    not_committed_sum = 0.0
    work_packets      = self.work_packets.all( :conditions => { :date => date_range } )

    work_packets.each do | work_packet |
      timesheet = work_packet.timesheet_row.timesheet

      if ( user.nil? or timesheet.user == user )
        if ( timesheet.committed )
          committed_sum     += work_packet.worked_hours
        else
          not_committed_sum += work_packet.worked_hours
        end
      end
    end

    return { :committed => committed_sum, :not_committed => not_committed_sum }
  end

private

  # Run via "validate".
  #
  def project_is_active()
    unless ( ( not self.active ) or self.project.nil? or self.project.active )
      errors.add( :base, 'Active tasks can only be associated with active projects' )
    end
  end

end
