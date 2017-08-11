########################################################################
# File::    timesheet.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Describe the behaviour of Timesheet objects. See below for
#           more details.
# ----------------------------------------------------------------------
#           07-Jan-2008 (ADH): Created.
########################################################################

class Timesheet < ActiveRecord::Base

  audited( {
    :except => [
      :lock_version,
      :updated_at,
      :created_at,
      :id,
      :committed_at,
      :start_day_cache
    ]
  } )

  USED_RANGE_COLUMN      = 'start_day_cache'
  DEFAULT_SORT_COLUMN    = 'start_day_cache'
  DEFAULT_SORT_DIRECTION = 'DESC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"
  AUTO_SORT_FIELD_LIMIT  = 16

  # Timesheets describe a week of activity by a particular
  # user. They are made up of TimesheetRows, where each row
  # corresponds to a particular Task. Within that row, each
  # day of activity for that task is represented by a
  # single WorkPacket. A User can have many Timesheets.

  belongs_to( :user )

  has_many( :timesheet_rows, { :dependent => :destroy        }, -> { order( :position ) } )
  has_many( :tasks,          { :through   => :timesheet_rows } )
  has_many( :work_packets,   { :through   => :timesheet_rows } )

  # Return a range of years allowed for a timesheet. Optionally pass 'true'
  # if you want an actual Date object range rather than just a year range.
  #
  def self.allowed_range( accurate = false )
    if ( WorkPacket.significant.count.zero? )
      range = ( Date.current.year - 2 )..( Date.current.year + 2 )
    else
      range = self.used_range
      range = ( range.first - 2 )..( range.last + 2 )
    end

    if ( accurate )
      ( Date.new( range.first, 1, 1 ) )..( Date.new( range.last, 12, 31 ) )
    else
      range
    end
  end

  # Return a range of years used by all current timesheets, or the allowed
  # range (see above) if there are no work packets. Optionally pass 'true'
  # if you want an actual Date object range rather than just a year range.
  #
  def self.used_range( accurate = false )
    return self.allowed_range( accurate ) if WorkPacket.significant.count.zero?

    first = WorkPacket.find_earliest_by_tasks()
    last  = WorkPacket.find_latest_by_tasks()

    if accurate
      ( first.date )..( last.date )
    else
      ( first.date.year )..( last.date.year )
    end
  end

  # Make sure the data is sane.

  validates_presence_of( :user_id )

  validates_inclusion_of(
    :week_number,
    :in => 1..53,
    :message => 'must lie between 1 and 53'
  )

  validates_inclusion_of(
    :year,
    :in => ->( record ) { record.class.allowed_range() },
    :message => "must lie between allowed range determined by work packets for active tasks, or the current year if there are none, +/- 2 years"
  )

  validates_inclusion_of(
    :committed,
    :in => [ true, false ],
    :message => "must be set to 'True' or 'False'"
  )

  validate( :column_sums_are_sane           )
  validate( :tasks_are_active_and_permitted )

  # Create TimesheetRow objects after saving, if not already
  # present. This must be done after because the ID of this
  # object instance is needed for the association.

  after_create :add_default_rows

  # Before an update, see if the 'committed' state is being set
  # to 'true'. If so, update the associated user's last committed
  # date.

  before_save :check_committed_state

  # Update the start date cache when records are saved or updated.

  before_save :update_start_day_cache

  # Is the given user permitted to do anything with this timesheet?
  # Admins and managers can view anything. Normal users can only view
  # their own timesheets.
  #
  def is_permitted_for?( user )
    ( user.id == self.user.id ) or ( user.privileged? )
  end

  # Is the given user permitted to update this timesheet? Admins can
  # modify anything. Managers can modify their own timesheets whether
  # committed or not, or any other timesheet provided it is not
  # committed. Normal users can only modify their own timesheets when
  # not committed.
  #
  # Note there is no special status awarded to admin-owned timesheets;
  # a manager can modify any not committed timesheet. This keeps the
  # model simple. Managers are trusted to only modify timesheets they
  # don't own when really necessary, but they can't revise history by
  # changing committed data.
  #
  def can_be_modified_by?( user )
    if ( user.admin? )
      true
    elsif ( user.manager? )
      ( user.id == self.user.id ) or ( not self.committed )
    else
      ( user.id == self.user.id ) and ( not self.committed )
    end
  end

  # Return a sorted array of week numbers which can be assigned to
  # the timesheet. Includes the current timesheet's already allocated
  # week.
  #
  def unused_weeks()
    timesheets = Timesheet.where( :user_id => self.user_id, :year => self.year )
    used_weeks = timesheets.select( :week_number ).map( &:week_number )

    range        = 1..Timesheet.get_last_week_number( self.year )
    unused_weeks = ( range.to_a - used_weeks )
    unused_weeks.push( self.week_number ) unless ( self.week_number.nil? )

    return unused_weeks.sort()
  end

  # Return the next (pass 'true') or previous (pass 'false') editable
  # week after this one, as a hash with properties 'week_number' and
  # 'timesheet'. The latter will be populated with a timesheet if there
  # is a not committed item in the found week, or nil if the week has no
  # associated timesheet yet. Returns nil altogether if no editable week
  # can be found (e.g. ask for previous from week 1, or all previous
  # weeks have committed timesheets on them).
  #
  # This operation may involve many database queries so is relatively slow.
  #
  def editable_week( nextweek )
    discover_week( nextweek ) do | timesheet |
      ( timesheet.nil? or not timesheet.committed )
    end
  end

  # As editable_week, but returns weeks for 'showable' weeks - that is,
  # only weeks where a timesheet owned by the current user already exists.
  #
  def showable_week( nextweek )
    discover_week( nextweek ) do | timesheet |
      ( not timesheet.nil? )
    end
  end

  # Add a row to the timesheet using the given task object. Does
  # nothing if a row containing that task is already present.
  # The updated timesheet is not saved - the caller must do this.
  # The new, added timesheet row object is returned, unless the
  # task is already included in the timesheet, in which case
  # the method returns 'nil'.
  #
  def add_row( task )
    unless self.tasks.include?( task )
      timesheet_row      = TimesheetRow.new
      timesheet_row.task = task

      self.timesheet_rows.push( timesheet_row )

      return timesheet_row
    else
      return nil
    end
  end

  # Count the hours across all rows on the given day number; 0 is
  # Sunday, 1-6 Monday to Saturday.
  #
  def column_sum( day_number )
    sum = 0.0

    # [TODO] Slow. Surely there's a better way...?

    self.timesheet_rows.all.each do | timesheet_row |
      work_packet = WorkPacket.find_by_timesheet_row_id(
        timesheet_row.id,
        :conditions => { :day_number => day_number }
      )

      sum += work_packet.worked_hours if work_packet
    end

    return sum
  end

  # Count the total number of worked hours in the whole timesheet.
  #
  def total_sum()
    return self.work_packets.sum( :worked_hours )
  end

  # Return the date of the first day for this timesheet as a string
  # augmented with week number for display purposes.
  #
  def start_day()
    return "#{ self.date_for( TimesheetRow::FIRST_DAY ) } (week #{ self.week_number })"
  end

  # Get the date of the first day of week 1 in the given year.
  # Note that sometimes, this can be in December the previous
  # year. Works on commercial weeks (Mon->Sun). Returns a Date.
  #
  def self.get_first_week_start( year )

    # Is Jan 1st already in week 1?

    date = Date.new( year, 1, 1 )

    if ( date.cweek == 1 )

      # Yes. Check December of the previous year.

      31.downto( 25 ) do | day |
        date = Date.new( year - 1, 12, day )

        # If we encounter a date in the previous year which has a week
        # number > 1, then that's the last week of the previous year. If
        # we're on Dec 31st that means that week 1 started on Jan 1st,
        # else in December.

        if ( date.cweek > 1 )
          return ( day == 31 ? Date.new( year, 1, 1 ) : Date.new( year - 1, 12, day + 1 ) )
        end
      end

    else

      # No. Walk forward through January until we reach week 1.

      2.upto( 7 ) do | day |
        date = Date.new( year, 1, day )
        return date if ( date.cweek == 1 )
      end
    end
  end

  # Get the date of the last day of the last week in the given year.
  # Note that sometimes, this can be in January in the following
  # year. Works on commercial weeks (Mon->Sun). Returns a Date.
  #
  def self.get_last_week_end( year )

    # Is Dec 31st already in week 1 for the next year?

    date = Date.new( year, 12, 31 )

    if ( date.cweek == 1 )

      # Yes. Check backwards through December to find the last day
      # in the higher week number.

      30.downto( 25 ) do | day |
        date = Date.new( year, 12, day )
        return Date.new( year, 12, day ) if ( date.cweek > 1 )
      end

    else

      # No. Check January of the following year to find the end
      # of the highest numbered week.

      1.upto( 6 ) do | day |
        date = Date.new( year + 1, 1, day )
        if ( date.cweek == 1 )
          return ( day == 1 ? Date.new( year, 12, 31 ) : Date.new( year + 1, 1, day - 1 ) )
        end
      end
    end
  end

  # Get the number of the last commercial week (Mon->Sun) in the
  # given year. This is usually 52, but is 53 for some years.
  #
  def self.get_last_week_number( year )

    # Is Dec 31st already in week 1 for the next year?

    date = Date.new( year, 12, 31 )

    if ( date.cweek == 1 )

      # Yes. Check backwards through December to find the last day
      # in the higher week number.

      30.downto( 25 ) do | day |
        date = Date.new( year, 12, day )
        return date.cweek if ( date.cweek > 1 )
      end

    else

      # No, so we have the highest week already.

      return date.cweek
    end
  end

  # Return a date string representing this timesheet on the given
  # day number. Day numbers are odd - 0 = Sunday at the *end* of this
  # timesheet's week, while 1-6 = Monday at the *start* of the week
  # through to Saturday inclusive (aligning with Ruby "cweek"). If an
  # optional second parameter is 'true', returns a Date object rather
  # than a string.
  #
  def date_for( day_number, as_date = false )
    Timesheet.date_for( self.year, self.week_number, day_number, as_date )
  end

  # Class method; as date_for, but pass explicitly the year, week number
  # and day number of interest. If an optional fourth parameter is 'true',
  # returns a Date object rather than a string.
  #
  def self.date_for( year, week_number, day_number, as_date = false )

    # Get the date of Monday, week 1 in this timesheet's year.
    # Add as many days as needed to get to Monday of the week
    # for this timesheet.

    date = Timesheet.get_first_week_start( year )
    date = date + ( ( week_number - 1 ) * 7 )

    # Add in the day number offset.

    date += TimesheetRow::DAY_ORDER.index( day_number )

    # Return in DD-Mth-YYYY format, or as a Date object?

    if ( as_date )
      return date
    else
      return date.strftime( '%d-%b-%Y' ) # Or ISO: '%Y-%m-%d'
    end
  end

private

  # Run via "validate".
  #
  def column_sums_are_sane
    TimesheetRow::DAY_ORDER.each do | day |
      if ( self.column_sum( day ) > 24 )
        errors.add( :base, "#{ TimesheetRow::DAY_NAMES[ day ] }: Cannot exceed 24 hours per day" )
      end
    end
  end

  # Run via "validate".
  #
  # Row validation catches individual rows being added before
  # we reach here. If a restricted user is taken off a task but
  # has already saved a timesheet including that row, though,
  # they'll get warned. Same thing for inactive tasks.
  #
  # Since the only way without hacking that the message can arise
  # (assuming correct functioning of views etc.) is for a task to
  # have changed state during the lifespan of an uncommitted
  # timesheet, use "no longer..." wording in the error messages.
  #
  def tasks_are_active_and_permitted
    self.tasks.all.each do | task |
      errors.add( :base, "Task '#{ task.augmented_title }' is no longer active and cannot be included" ) unless task.active

      if ( self.user.try( :restricted? ) )
        errors.add( :base, "Inclusion of task '#{ task.augmented_title }' is no longer permitted" ) unless self.user.task_ids.include?( task.id )
      end
    end
  end

  # Run via "after_create".
  #
  def add_default_rows
    User.find( self.user_id ).control_panel.tasks.all.each do | task |
      add_row( task ) if ( task.active )
    end
  end

  # Run via "before_safe".
  #
  def check_committed_state
    if ( self.committed && self.user )
      self.committed_at = self.user.last_committed = Time.new
      self.user.save!
    end
  end

  # Run via "before_safe".
  #
  def update_start_day_cache
    self.start_day_cache = self.date_for(
      TimesheetRow::FIRST_DAY,
      true # Return as a Date rather than a String

    ).to_datetime.in_time_zone( 'UTC' ) # Rails 3 gotcha/bug; auto-conversion to TimeWithZone uses *server's local time zone* rather than UTC+0, contrary to Rails defaults elsewhere; typical result is the cache column ends up in the 'wrong day' unless server is also at UTC +0.
  end

  # Back-end to editable_week and showable_week. See those functions for
  # details. Call with the next/previous week boolean and pass a block;
  # this is given a timesheet or nil; evaluate 'true' to return details
  # on the item or 'false' to move on to the next week.
  #
  def discover_week( nextweek )
    year  = self.year
    owner = self.user_id

    if ( nextweek )
      inc   = 1
      week  = self.week_number + 1
      limit = Timesheet.get_last_week_number( year ) + 1

      return if ( week >= limit )
    else
      inc   = -1
      week  = self.week_number - 1
      limit = 0

      return if ( week <= limit )
    end

    while ( week != limit )
      timesheet = Timesheet.find_by_user_id_and_year_and_week_number(
        owner, year, week
      )

      if ( yield( timesheet ) )
        return { :week_number => week, :timesheet => timesheet }
      end

      week += inc
    end

    return nil
  end
end
