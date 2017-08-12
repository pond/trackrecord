########################################################################
# File::    work_packet.rb
# (C)::     Hipposoft 2007
#
# Purpose:: Describe the behaviour of WorkPacket objects. See below
#           for more details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class WorkPacket < ActiveRecord::Base

  # Allow a User to log a number of hours worked against the Task in
  # the TimesheetRow to which the WorkPacket belongs.

  belongs_to( :timesheet_row )
  scope :significant, -> { where( 'worked_hours > 0.0' ) }

  # Make sure the data is sane.

  validates_presence_of( :timesheet_row_id )
  validates_numericality_of(
    :worked_hours,
    :less_than_or_equal_to    => 24,
    :greater_than_or_equal_to => 0
  )

  validates_inclusion_of(
    :day_number,
    :in => 0..6 # 0 = Sun, 6 = Sat, as per Date::DAYNAMES
  )

  # Set a Date indicating the start of the day which the work packet
  # represents whenever the work packet is saved. This helps a lot with
  # reports, since a report may have to query large numbers of packets
  # by date - we can make the database do that work. It isn't always
  # faster than doing that locally, surprisingly, but the code is much
  # more legible and maintainable.

  before_save( :set_date )

  # Return the earliest (first by date) work packet, either across all tasks
  # (pass nothing) or for the given tasks specified as an array of task IDs.
  # The work packet may be in either a not committed or committed timesheet.
  #
  def self.find_earliest_by_tasks( task_ids = [] )
    return WorkPacket.find_first_by_tasks_and_order( task_ids, { 'date' => :asc } )
  end

  # Return the latest (last by date) work packet, either across all tasks
  # (pass nothing) or for the given tasks specified as an array of task IDs.
  # The work packet may be in either a not committed or committed timesheet.
  #
  def self.find_latest_by_tasks( task_ids = [] )
    return WorkPacket.find_first_by_tasks_and_order( task_ids, { 'date' => :desc } )
  end

  # Support find_earliest_by_tasks and find_latest_by_tasks. Pass an array
  # of task IDs and a sort order (Hash, e.g. "{ 'date' => :asc }").
  #
  def self.find_first_by_tasks_and_order( task_ids, order_hash )
    if ( task_ids.count.zero? )
      return WorkPacket.significant.order( order_hash ).first

    else
      joins      = :timesheet_row
      conditions = { :timesheet_rows => { :task_id => task_ids } }
      return WorkPacket.significant.joins( joins ).where( conditions ).order( order_hash ).first

    end
  end

private

  # Run via "before_save".
  #
  def set_date
    if ( self.timesheet_row and self.timesheet_row.timesheet )
      self.date = self.timesheet_row.timesheet.date_for(
        self.day_number,
        true # Return as a Date rather than a String
      )
    else
      self.date = Date.today
    end
  end

end
