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

  # WorkPacket objectallow a User to log a number of hours worked
  # against the Task in the TimesheetRow to which the WorkPacket
  # belongs.

  belongs_to( :timesheet_row )
  scope :significant, :conditions => 'worked_hours > 0.0'

  # Security controls.

  attr_accessible(
    :worked_hours,
    :description
  )

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

  # Find work packets in rows related to the given task ID, held in timesheets
  # owned by the given user ID, between the Dates in the given range. The range
  # MUST be inclusive, for reasons discussed below. The results are sorted by
  # work packet date, descending.
  #
  # The task and user IDs are optional. All tasks and/or users will be
  # included in the count if the given task and/or user ID is nil. The date
  # range is mandatory.
  #
  # IMPORTANT - at the time of writing, Rails 2.1 (and earlier versions) will
  # build a BETWEEN statement in SQL with the given range. Although SQL says
  # that the values on either side of BETWEEN should be treated as inclusive,
  # i.e. a Ruby "a..b" kind of range, some databases may treat the right side
  # as exclusive; PostgreSQL is fine, but if in doubt you need to go to the
  # Rails console and run a test. For example, issue something like this:
  #
  #   User.all.collect { |x| x.id }.sort
  #
  # Note any two consecutive IDs listed - e.g. "[1, 2, ...]" - 1 and 2 will do.
  # Use these as part of range conditions for a find:
  #
  #   User.find(:all, :conditions => { :id => 1..2 } )
  #
  # Assuming you actually *have* users with IDs 1 and 2, then both should be
  # returned. If you only get one, BETWEEN isn't working and you need to use
  # another database or change the function below to do something else (e.g.
  # hard-code a condition using ">=" and "<=" if your database supports those
  # operators).
  #
  # A final twist is that Rails' "to_s( :db )" operator assumes all ranges are
  # inclusive and generates SQL accordingly. There's a ticket for this in the
  # case of dates:
  #
  #   http://dev.rubyonrails.org/ticket/8549
  #
  # ...but actually Rails seems to do this for any kind of range - e.g. change
  # the "1..2" to "1...2" in the User find above and note that the generated
  # SQL is the same. We'd expect it to only look for a user with id '1' (or
  # between 1 and 1) in this case.
  #
  # As a result, ensure you only ever pass inclusive ranges to this function.
  #
  def self.find_by_task_user_and_range( range, task_id = nil, user_id = nil )
    return WorkPacket.find_by_task_user_range_and_committed(
      range,
      nil,
      task_id,
      user_id
    )
  end

  # As find_by_task_user_and_range, but only counts work packets belonging to
  # committed timesheets.
  #
  def self.find_committed_by_task_user_and_range( range, task_id = nil, user_id = nil )
    # TODO: Use with_scope? Can we cope with the 'nil' case cleanly?

    return WorkPacket.find_by_task_user_range_and_committed(
      range,
      true,
      task_id,
      user_id
    )
  end

  # As find_by_task_user_and_range, but only counts work packets belonging to
  # timesheets which are not committed.
  #
  def self.find_not_committed_by_task_user_and_range( range, task_id = nil, user_id = nil )
    return WorkPacket.find_by_task_user_range_and_committed(
      range,
      false,
      task_id,
      user_id
    )
  end

  # Support find_by_task_user_and_range, find_committed_by_task_user_and_range
  # and find_not_committed_by_task_user_and_range. An extra mandatory second
  # parameter must be set to 'true' to only include work packets from committed
  # timesheets, 'false' for not committed timesheets and 'nil' for either.
  #
  def self.find_by_task_user_range_and_committed( range, committed, task_id = nil, user_id = nil )

    # The 'include' part needs some explanation. We include the timesheet rows,
    # a second order association, because the rows lead to tasks and timesheets.
    # We need to eager-load tasks because the search is limited by task ID. We
    # need to eager-load timesheets because they lead to users and the search is
    # also limited by user ID. Rails supports eager-loading of third and deeper
    # order associations through passing hashes in as the value to ":include".
    # Each key's value is the next level of association. So :timesheet_row is
    # at the second order, pointing to an array giving two third order things;
    # :task and, itself a hash key, :timesheet; since it is a hash key,
    # :timesheet's value is the second-order association of timesheets, or the
    # fourth-order association of the work packets - :user.
    #
    # Ultimately eager-loading means LEFT OUTER JOIN in SQL statements. Due to
    # the way that ActiveRecord assembles the query, using :include rather than
    # :joins with some hard-coded SQL makes for a very verbose query in the
    # "find" case; it's nice and compact for "sum", though. In any event, at
    # least it is a query generated entirely through the database adapter, so
    # it stands a fighting chance of working fine on multiple database types.

    conditions = { :date => range }
    conditions[ 'tasks.id' ] = task_id unless task_id.nil?
    conditions[ 'users.id' ] = user_id unless user_id.nil?
    conditions[ 'timesheets.committed' ] = committed unless committed.nil?

    return WorkPacket.all(
      :include     => { :timesheet_row => [ :task, { :timesheet => :user } ] },
      :conditions  => conditions,
      :order       => 'date DESC'
    )

  end

  # Return the earliest (first by date) work packet, either across all tasks
  # (pass nothing) or for the given tasks specified as an array of task IDs.
  # The work packet may be in either a not committed or committed timesheet.
  #
  def self.find_earliest_by_tasks( task_ids = [] )
    return WorkPacket.find_first_by_tasks_and_order( task_ids, 'date ASC' )
  end

  # Return the latest (last by date) work packet, either across all tasks
  # (pass nothing) or for the given tasks specified as an array of task IDs.
  # The work packet may be in either a not committed or committed timesheet.
  #
  def self.find_latest_by_tasks( task_ids = [] )
    return WorkPacket.find_first_by_tasks_and_order( task_ids, 'date DESC' )
  end

  # Support find_earliest_by_tasks and find_latest_by_tasks. Pass an array
  # of task IDs and a sort order (SQL fragment, e.g. "date ASC").
  #
  def self.find_first_by_tasks_and_order( task_ids, order )
    if ( task_ids.empty? )
      return WorkPacket.significant.first( :order => order )
    else
      return WorkPacket.significant.first(
        :include    => [ :timesheet_row ],
        :conditions => [ 'timesheet_rows.task_id IN (?)', task_ids ],
        :order      => order
      )
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
      ).to_datetime.in_time_zone( 'UTC' ) # Rails 3 gotcha/bug; auto-conversion to TimeWithZone uses *server's local time zone* rather than UTC+0, contrary to Rails defaults elsewhere; typical result is the cache column ends up in the 'wrong day' 
    else
      self.date = Time.current
    end
  end

end
