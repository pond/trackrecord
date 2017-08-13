require File.dirname(__FILE__) + '/../test_helper'

class TimesheetTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 1356, Timesheet.count, "Wrong timesheet count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "02 basic model paranoia" do
    # Basic validation check over all existing data

    Timesheet.find_each do | t |
      refute_nil t.user, "Timesheet #{ t.id } has no user"
      refute_nil t.timesheet_rows, "Timesheet #{ t.id } has no row array"
      refute_nil t.tasks, "Timesheet #{ t.id } has no row array"
      refute_nil t.work_packets, "Timesheet #{ t.id } has no work packets array"
      assert_equal t.timesheet_rows.count, t.tasks.count, "Timesheet #{ t.id } has a mismatched rows-vs-tasks count"
      assert_equal t.timesheet_rows.count * 7, t.work_packets.count, "Timesheet #{ t.id } has a mismatched rows-vs-work-packets count"
    end

    # Simple blank no-save check

    t = Timesheet.new
    refute t.save, "A blank timesheet was saved"

    # Create a valid timesheet with two rows

    admin = User.admins.last
    assert_equal 0, admin.control_panel.tasks.count, "Unexpected admin user control panel tasks"

    t.user = admin
    t.week_number = 1
    t.year = 2012
    assert t.save, "Could not save a valid timesheet (A): #{ t.errors.messages }"

    tr1 = TimesheetRow.new
    tr1.timesheet = t
    tr1.task = Task.active.first
    assert tr1.save, "Could not save a valid timesheet row for a timesheet (A)"

    tr2 = TimesheetRow.new
    tr2.timesheet = t
    tr2.task = Task.active.last
    assert tr2.save, "Could not save a valid timesheet row for a timesheet (B)"

    TimesheetRow::DAY_ORDER.each_with_index do | day_number, index |
      wp = tr1.work_packets.where( :day_number => day_number ).first
      wp.worked_hours = ( index + 1 ) / 2.0
      assert wp.save, "Could not save a valid work packet for a timesheet (A)"
    end

    TimesheetRow::DAY_ORDER.each_with_index do | day_number, index |
      wp = tr2.work_packets.where( :day_number => day_number ).first
      wp.worked_hours = index + 1
      assert wp.save, "Could not save a valid work packet for a timesheet (B)"
    end

    assert t.save, "Could not save a valid timesheet (B): #{ t.errors.messages }"

    # Now change individual validated fields to make sure saving fails

    t.week_number = 0
    refute t.save, "An invalid timesheet was saved (A)"
    t.week_number = 54
    refute t.save, "An invalid timesheet was saved (B)"
    t.week_number = 1
    assert t.save, "Could not save a valid timesheet (C): #{ t.errors.messages }"

    t.user = nil
    refute t.save, "An invalid timesheet was saved (C)"
    t.user = admin
    assert t.save, "Could not save a valid timesheet (D): #{ t.errors.messages }"

    t.year = 1800
    refute t.save, "An invalid timesheet was saved (D)"
    t.year = 2100
    refute t.save, "An invalid timesheet was saved (E)"
    t.year = 2012
    assert t.save, "Could not save a valid timesheet (E): #{ t.errors.messages }"

    # More complicated checks - an inactive task in the rows

    tr1.task.active = false
    assert tr1.task.save, "Could not save a valid task for a timesheet (A)"
    refute t.save, "An invalid timesheet was saved (F): #{ t.errors.messages }"
    tr1.task.active = true
    assert tr1.task.save, "Could not save a valid task for a timesheet (B)"
    assert t.save, "Could not save a valid timesheet (F): #{ t.errors.messages }"

    # More complicated checks - a restricted user with one
    # prohibited task in the rows (start with no prohibited
    # tasks to verify it saves OK, then change, then restore
    # everything as it was).

    tr1task = tr1.task
    tr2task = tr2.task

    u = User.find( 14 )

    tr1.task = u.tasks.first
    tr2.task = u.tasks.last
    assert tr1.save, "Could not save a valid row for a timesheet (A)"
    assert tr2.save, "Could not save a valid row for a timesheet (B)"

    t.user = u
    assert t.save, "Could not save a valid timesheet (G): #{ t.errors.messages }"

    # Need to bypass validation on the row save, else it will notice
    # it is part of a timesheet owned by a restricted user and refuse
    # to save because it's being associated with a prohibited task.

    tr1.task = ( Task.active - u.tasks ).first
    assert tr1.save(:validate => false), "Could not save a row for a timesheet (C)"

    refute t.save, "An invalid timesheet was saved (G)"

    t.user = admin
    assert t.save, "Could not save a valid timesheet (H): #{ t.errors.messages }"

    tr1.task = tr1task
    tr2.task = tr2task
    assert tr1.save, "Could not save a valid row for a timesheet (D)"
    assert tr2.save, "Could not save a valid row for a timesheet (E)"

    # Week 1, 2012 starts on the 2nd January 2011.
    # Week 1, 2011 starts on the 3rd January 2011.
    # Week 1, 2014 starts on *30th December 2013*.

    assert_equal Date.new( 2012, 1, 2 ), t.start_day_cache.to_date, "Timesheet start day cache incorrect (A)"

    t.year = 2011
    assert t.save, "Could not save a valid timesheet (I): #{ t.errors.messages }"
    assert_equal Date.new( 2011, 1, 3 ), t.start_day_cache.to_date, "Timesheet start day cache incorrect (B)"

    t.year = 2014
    assert t.save, "Could not save a valid timesheet (J): #{ t.errors.messages }"
    assert_equal Date.new( 2013, 12, 30 ), t.start_day_cache.to_date, "Timesheet start day cache incorrect (C)"

    # Force a > 24 hour column sum in the middle the week

    wp = tr1.work_packets[ 3 ]
    hours = wp.worked_hours
    wp.worked_hours = 24
    assert wp.save, "Could not save a valid work packet for a timesheet (C)"

    refute t.save, "Should not be able to save a timesheet with > 24 hour totals in any columns"

    wp.worked_hours = hours
    assert wp.save, "Could not save a valid work packet for a timesheet (D)"

    assert t.save, "Could not save a valid timesheet (K): #{ t.errors.messages }"

    # Since having this timesheet set up is handy for a few other
    # checks, also make sure a few utility functions work, even
    # though this wider test is really about basic database stuff.

    TimesheetRow::DAY_ORDER.each_with_index do | day_number, index |
      sum = t.column_sum( day_number )
      val = index + 1
      assert_equal val + ( val / 2.0 ), sum, "Unexpected column sum on day #{ day_number }"
    end

    # 1+2+3+4+5+6+7 plus half of that again is 42. This is too much
    # of a coincidence and clearly has planetary significance.

    assert_equal 42, t.total_sum, "Unexpected total sum"
    # 
    # after_create :add_default_rows
    # before_update :check_committed_state
    # 

    # Check the work packets get deleted with the row

    taskbefore = Task.count
    trbefore = TimesheetRow.count
    wpbefore = WorkPacket.count

    t.destroy

    taskafter = Task.count
    trafter = TimesheetRow.count
    wpafter = WorkPacket.count

    assert_equal taskbefore, taskafter, "Tasks were unexpected deleted"
    assert_equal 2, trbefore - trafter, "Timesheet row count did not drop as expected when a timesheet was deleted"
    assert_equal 14, wpbefore - wpafter, "Work packet count did not drop as expected when a timesheet was deleted"
  end

  # =========================================================================
  # Test access permission methods.
  # =========================================================================

  test "03 permissions" do

    # User 14 is a normal, restricted user with a permitted task list.

    u       = User.find( 14 )
    manager = User.managers.first
    admin   = User.admins.last # (sic.)

    # Timesheets owned by a restricted user.

    t = u.timesheets.where( :committed => true ).first

    assert t.is_permitted_for?( u       ), "Timesheet should be permitted for normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Committed timesheet should not be mutable by normal user"
    refute t.can_be_modified_by?( manager ), "Committed timesheet should not be mutable by non-owning manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"

    t = u.timesheets.where( :committed => false ).first

    assert t.is_permitted_for?( u       ), "Timesheet should be permitted for normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    assert t.can_be_modified_by?( u       ), "Uncommitted timesheet should be mutable by normal user"
    assert t.can_be_modified_by?( manager ), "Uncommitted timesheet should be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"

    # Timesheets not owned by a restricted user, but owned a
    # manager in this case. Managers can modify their own
    # timesheets even if committed.

    t = manager.timesheets.where( :committed => true ).first

    refute t.is_permitted_for?( u       ), "Timesheet should not be permitted for non-owning normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Committed timesheet should not be mutable by normal user"
    assert t.can_be_modified_by?( manager ), "Committed timesheet should be mutable by owning manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"

    t = manager.timesheets.where( :committed => false ).first

    refute t.is_permitted_for?( u       ), "Timesheet should not be permitted for non-owning normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Timesheet should not be mutable by non-owning normal user"
    assert t.can_be_modified_by?( manager ), "Uncommitted timesheet should be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"

    # For completion - admin-owned timesheets. There's nothing
    # expected to be special about these. They're just not owned
    # by the restricted user in 'u' or the manager in 'manager'.

    t = admin.timesheets.where( :committed => true ).first

    refute t.is_permitted_for?( u       ), "Timesheet should not be permitted for non-owning normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Committed timesheet should not be mutable by normal user"
    refute t.can_be_modified_by?( manager ), "Committed timesheet should not be mutable by non-owning manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"

    t = admin.timesheets.where( :committed => false ).first

    refute t.is_permitted_for?( u       ), "Timesheet should not be permitted for non-owning normal user"
    assert t.is_permitted_for?( manager ), "Timesheet should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Timesheet should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Timesheet should not be mutable by non-owning normal user"
    assert t.can_be_modified_by?( manager ), "Uncommitted timesheet should be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any timesheet should be mutable by admin"
  end

  # =========================================================================
  # Basic date operations.
  # =========================================================================

  test "04 basic date operations" do

    # Start/end of commercial year and commercial week count class methods.

    years  = ( 1998..2016 ).to_a
    weeks  = [
      53, # 1998
      52, # 1999
      52, # 2000
      52, # 2001
      52, # 2002
      52, # 2003
      53, # 2004
      52, # 2005
      52, # 2006
      52, # 2007
      52, # 2008
      53, # 2009
      52, # 2010
      52, # 2011
      52, # 2012
      52, # 2013
      52, # 2014
      53, # 2015
      52  # 2016
    ]
    starts = [
      Date.new( 1997, 12, 29 ),
      Date.new( 1999, 01, 04 ),
      Date.new( 2000, 01, 03 ),
      Date.new( 2001, 01, 01 ),
      Date.new( 2001, 12, 31 ),
      Date.new( 2002, 12, 30 ),
      Date.new( 2003, 12, 29 ),
      Date.new( 2005, 01, 03 ),
      Date.new( 2006, 01, 02 ),
      Date.new( 2007, 01, 01 ),
      Date.new( 2007, 12, 31 ),
      Date.new( 2008, 12, 29 ),
      Date.new( 2010, 01, 04 ),
      Date.new( 2011, 01, 03 ),
      Date.new( 2012, 01, 02 ),
      Date.new( 2012, 12, 31 ),
      Date.new( 2013, 12, 30 ),
      Date.new( 2014, 12, 29 ),
      Date.new( 2016, 01, 04 )
    ]
    ends = [
      Date.new( 1999, 01, 03 ),
      Date.new( 2000, 01, 02 ),
      Date.new( 2000, 12, 31 ),
      Date.new( 2001, 12, 30 ),
      Date.new( 2002, 12, 29 ),
      Date.new( 2003, 12, 28 ),
      Date.new( 2005, 01, 02 ),
      Date.new( 2006, 01, 01 ),
      Date.new( 2006, 12, 31 ),
      Date.new( 2007, 12, 30 ),
      Date.new( 2008, 12, 28 ),
      Date.new( 2010, 01, 03 ),
      Date.new( 2011, 01, 02 ),
      Date.new( 2012, 01, 01 ),
      Date.new( 2012, 12, 30 ),
      Date.new( 2013, 12, 29 ),
      Date.new( 2014, 12, 28 ),
      Date.new( 2016, 01, 03 ),
      Date.new( 2017, 01, 01 )
    ]

    years.each_with_index do | year, index |
      start_date = starts[ index ]
      end_date   = ends[ index ]
      week_count = weeks[ index ]

      assert_equal start_date, Timesheet.get_first_week_start( year ), "Incorrect start date for #{ year }"
      assert_equal end_date,   Timesheet.get_last_week_end( year ),    "Incorrect end date for #{ year }"
      assert_equal week_count, Timesheet.get_last_week_number( year ), "Incorrect week count for #{ year }"
    end

    # Date-related class method.

    assert_equal Date.new( 1997, 12, 29 ),                        Timesheet.date_for( 1998,  1, 1, true  ), "Unexpected date (O)"
    assert_equal Date.new( 1997, 12, 29 ).strftime( '%d-%b-%Y' ), Timesheet.date_for( 1998,  1, 1, false ), "Unexpected date (P)"
    assert_equal Date.new( 1997, 12, 30 ),                        Timesheet.date_for( 1998,  1, 2, true  ), "Unexpected date (Q)"
    assert_equal Date.new( 1997, 12, 30 ).strftime( '%d-%b-%Y' ), Timesheet.date_for( 1998,  1, 2, false ), "Unexpected date (R)"
    assert_equal Date.new( 1998, 01, 04 ),                        Timesheet.date_for( 1998,  1, 0, true  ), "Unexpected date (S)"
    assert_equal Date.new( 1998, 01, 04 ).strftime( '%d-%b-%Y' ), Timesheet.date_for( 1998,  1, 0, false ), "Unexpected date (T)"
    assert_equal Date.new( 1998, 12, 28 ),                        Timesheet.date_for( 1998, 53, 1, true  ), "Unexpected date (U)"
    assert_equal Date.new( 1998, 12, 28 ).strftime( '%d-%b-%Y' ), Timesheet.date_for( 1998, 53, 1, false ), "Unexpected date (V)"
    assert_equal Date.new( 1999, 01, 03 ),                        Timesheet.date_for( 1998, 53, 0, true  ), "Unexpected date (W)"
    assert_equal Date.new( 1999, 01, 03 ).strftime( '%d-%b-%Y' ), Timesheet.date_for( 1998, 53, 0, false ), "Unexpected date (X)"
  end

  # =========================================================================
  # Test some general utility methods.
  # =========================================================================

  test "05 utility methods" do

    # Timesheet next/previous/available weeks.

    u     = User.find( 14 )
    t     = u.timesheets.where( :week_number => 17, :year => 2008 ).first
    year  = t.year
    weeks = ( 1..( Timesheet.get_last_week_number( year ) ) ).to_a

    ts = u.timesheets.where( :year => year ).map( &:week_number ) - [ t.week_number ]
    assert_equal ( weeks - ts ).sort, t.unused_weeks(), "Unexpected unused week result (A)"

    hard_coded = [ 1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 14, 15, 17, 19, 20, 22, 24, 25, 26, 27, 29, 31, 33, 34, 35, 36, 38, 39, 40, 41, 42, 43, 45, 47, 48, 49, 51, 52 ]
    assert_equal hard_coded, t.unused_weeks(), "Unexpected unused week result (B)"

    # User has no timesheet for week 15 or 19, but committed timesheets in between.

    assert_equal( { :week_number => 19, :timesheet => nil }, t.editable_week( true  ), "Unexpected 'editable_week' result (A)" )
    assert_equal( { :week_number => 15, :timesheet => nil }, t.editable_week( false ), "Unexpected 'editable_week' result (B)" )

    assert_equal( { :week_number => 18, :timesheet => Timesheet.find( 1333 ) }, t.showable_week( true  ), "Unexpected 'showable_week' result (A)" )
    assert_equal( { :week_number => 16, :timesheet => Timesheet.find( 1355 ) }, t.showable_week( false ), "Unexpected 'showable_week' result (B)" )

    t = u.timesheets.where( :week_number => 18, :year => year ).first

    # Week 17 is not committed, so it's editable even from week 18's perspective.

    assert_equal( { :week_number => 19, :timesheet => nil                    }, t.editable_week( true  ), "Unexpected 'editable_week' result (C)" )
    assert_equal( { :week_number => 17, :timesheet => Timesheet.find( 1353 ) }, t.editable_week( false ), "Unexpected 'editable_week' result (D)" )

    assert_equal( { :week_number => 21, :timesheet => Timesheet.find( 1343 ) }, t.showable_week( true  ), "Unexpected 'showable_week' result (C)" )
    assert_equal( { :week_number => 17, :timesheet => Timesheet.find( 1353 ) }, t.showable_week( false ), "Unexpected 'showable_week' result (D)" )

    # The first admin user has timesheets covering all of 2007, except for
    # week 1 which we'll add now. All are committed.

    u = User.admins.first

    ts = u.timesheets.where( :year => 2007 )
    t  = ts.where( :week_number => 26 ).first; ts.shift; ts.map!( &:week_number )

    t2 = t.dup
    t2.week_number = 1
    t2.save!( :validate => false ) # As year is out of "allowed" +/- 2-year range vs "today"

    assert_equal [ t.week_number ], t.unused_weeks, "Unexpected unused week result (C)"

    assert_nil t.editable_week( true  ), "Unexpected 'editable_week' result (E)"
    assert_nil t.editable_week( false ), "Unexpected 'editable_week' result (F)"

    assert_equal( { :week_number => 27, :timesheet => Timesheet.find( 4  ) }, t.showable_week( true  ), "Unexpected 'showable_week' result (E)" )
    assert_equal( { :week_number => 25, :timesheet => Timesheet.find( 43 ) }, t.showable_week( false ), "Unexpected 'showable_week' result (F)" )

    assert_equal "25-Jun-2007 (week 26)",                         t.start_day,            "Unexpected date (A)"
    assert_equal Date.new( 2007, 06, 25 ),                        t.date_for( 1, true  ), "Unexpected date (B)"
    assert_equal Date.new( 2007, 06, 25 ).strftime( '%d-%b-%Y' ), t.date_for( 1, false ), "Unexpected date (C)"
    assert_equal Date.new( 2007, 07, 01 ),                        t.date_for( 0, true  ), "Unexpected date (D)"
    assert_equal Date.new( 2007, 07, 01 ).strftime( '%d-%b-%Y' ), t.date_for( 0, false ), "Unexpected date (E)"
    assert_equal Date.new( 2007, 06, 26 ),                        t.date_for( 2, true  ), "Unexpected date (F)"
    assert_equal Date.new( 2007, 06, 26 ).strftime( '%d-%b-%Y' ), t.date_for( 2, false ), "Unexpected date (G)"

    # Check high-level row addition works.

    count = t.timesheet_rows.count

    tr1 = t.add_row( Task.active.first )
    refute_nil tr1, "Couldn't add row"

    tr2 = t.add_row( Task.active.first )
    assert_nil tr2, "Added same task twice"

    assert_equal 1, t.timesheet_rows.count - count, "Timesheet row count did not increase as expected"

    tr1.destroy
    t2.destroy
  end
end
