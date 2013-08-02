########################################################################
# File::    timesheet_row.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Describe the behaviour of TimesheetRow objects. See below
#           for more details.
# ----------------------------------------------------------------------
#           07-Jan-2008 (ADH): Created.
########################################################################

class TimesheetRow < ActiveRecord::Base

  # Timesheets are made up of TimesheetRows, where each row
  # corresponds to a particular Task. Within that row, each
  # day of activity for that task is represented by a
  # single WorkPacket.

  belongs_to( :timesheet )
  belongs_to( :task      )

  has_many( :work_packets, { :dependent => :destroy } )

  acts_as_list( { :scope => :timesheet } )

  # Security controls - *no* mass assignments, please.

  attr_accessible()

  # Make sure the data is sane.

  validates_presence_of( :timesheet_id, :task_id )
  validate( :task_is_active_and_permitted )

  # Create WorkPacket objects after saving, if not already
  # present. This must be done after because the ID of this
  # object instance is needed for the association.

  after_create :add_work_packets

  # Day number order within a row - Monday to Sunday. While
  # originally this was intended to be potentially mutable,
  # it became too onerous elsewhere to calculate week numbers
  # and far simpler/more reliable/faster to just use "cweek"
  # in Ruby. Thus weeks must always run Monday->Sunday.

  DAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ]
  FIRST_DAY = DAY_ORDER[ 0 ]
  LAST_DAY  = DAY_ORDER[ 6 ]
  DAY_NAMES = Date::DAYNAMES

  # Return the sum of hours in work packets on this row.
  #
  def row_sum()
    return self.work_packets.sum( :worked_hours )
  end

private

  # Run via "validate".
  #
  def task_is_active_and_permitted
    errors.add( :base, 'Only active tasks may be included' ) unless self.task.active

    if ( self.timesheet.user.restricted? )
      errors.add( :base, 'Inclusion of this task is not permitted' ) unless self.timesheet.user.task_ids.include?( self.task.id )
    end
  end

  # Run via "after_create".
  #
  def add_work_packets
    DAY_ORDER.each do | day |
      work_packet               = WorkPacket.new
      work_packet.day_number    = day
      work_packet.worked_hours  = 0
      work_packet.timesheet_row = self
      work_packet.save!
    end
  end
end
