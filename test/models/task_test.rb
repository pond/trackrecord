require File.dirname(__FILE__) + '/../test_helper'

class TaskTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 371, Task.count, "Wrong task count"
  end

  # =========================================================================
  # More complicated data checks.
  # =========================================================================

  test "02 make sure task metrics look sane" do
    assert_equal 123, Task.active.count,       "Wrong active task count"
    assert_equal 248, Task.inactive.count,     "Wrong inactive task count"
    assert_equal   0, Task.unassigned.count,   "Wrong unassigned task count"
    assert_equal 317, Task.billable.count,     "Wrong billable task count"
    assert_equal  54, Task.not_billable.count, "Wrong not billable task count"

    # Database checks for multiple AREL-based conditions in potentially
    # differing orders.

    assert_equal  96, Task.active.billable.count,       "Wrong billable task count"
    assert_equal  27, Task.active.not_billable.count,   "Wrong not billable active task count"
    assert_equal 221, Task.inactive.billable.count,     "Wrong billable inactive task count"
    assert_equal  27, Task.inactive.not_billable.count, "Wrong not billable inactive task count"

    assert_equal  96, Task.billable.active.count,       "Wrong active billable task count"
    assert_equal  27, Task.not_billable.active.count,   "Wrong active not billable task count"
    assert_equal 221, Task.billable.inactive.count,     "Wrong inactive billable task count"
    assert_equal  27, Task.not_billable.inactive.count, "Wrong inactive not billable task count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "03 basic model paranoia" do
    t = Task.new
    refute_nil t.code, "New task has no assigned code"
    refute t.save, "A blank task was saved"
    t.title = "New task"
    assert t.save, "A valid task could not be saved"

    t.duration = "foo"
    refute t.save, "Shouldn't be able to save a task with a non-numeric duration"
    t.duration = -10
    refute t.save, "Shouldn't be able to save a task with a negative duration"

    t.destroy
  end

  # =========================================================================
  # Test different mechanisms for task creation and protections against
  # assignment of inactive projects.
  # =========================================================================

  test "04 initializer variations and inactive projects" do
    t = Task.new( :title => "Hello" ) # Overrides default assignments so no duration is set
    refute t.save, "An invalid task with a nil duration was saved"

    t = Task.new( :title => "Hello", :duration => 10 )
    assert t.save, "A valid task could not be saved"

    t.destroy

    # User 14 is a normal, restricted user with a control panel that
    # specifies a valid active project as a new task default.

    u = User.find( 14 )
    p = u.control_panel.project
    t = Task.new( nil, u )
    t.title = "New task"
    assert_equal t.project, p, "New for-user task has unexpected project"
    assert t.save, "A valid task could not be saved"

    t.destroy

    # Temporarily change the user's control panel project to be inactive.

    p.active = false
    p.save!

    t = Task.new( nil, u )
    t.title = "New task"
    assert_nil t.project, "New for-user task was assigned an inactive project"
    assert t.save, "A valid task could not be saved"

    t.destroy

    # Force the issue by attempting to assign the project manually.

    t = Task.new( nil, u )
    t.title = "New task"
    t.project = p
    refute t.save, "A invalid task with an inactive project was saved"
    assert_equal "Active tasks can only be associated with active projects", t.errors.try( :messages ).try( :[], :base ).try( :[], 0 ), "Expected error message not present"

    p.active = true
    p.save!
  end

  # =========================================================================
  # Test access permission methods.
  # =========================================================================

  test "05 permissions" do

    # User 14 is a normal, restricted user with a permitted task list.

    u       = User.find( 14 )
    manager = User.managers.first
    admin   = User.admins.first

    t = u.tasks.first

    assert t.is_permitted_for?( u       ), "Task should be permitted for normal user"
    assert t.is_permitted_for?( manager ), "Task should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Task should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Task should not be mutable by normal user"
    assert t.can_be_modified_by?( manager ), "Active task should be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any task should be mutable by admin"

    t = Task.first
    assert t.active, "Unexpected data set; this task should be active"
    refute u.tasks.include?( t ), "Unexpected data set; didn't think this task was listed for this user"

    refute t.is_permitted_for?( u       ), "Task should not be permitted for user"
    assert t.is_permitted_for?( manager ), "Task should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Task should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Task should not be mutable by normal user"
    assert t.can_be_modified_by?( manager ), "Active task should be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any task should be mutable by admin"

    t = Task.inactive.first
    refute u.tasks.include?( t ), "Inactive task should not be listed for this user"

    refute t.is_permitted_for?( u       ), "Inactive task should not be permitted for user"
    assert t.is_permitted_for?( manager ), "Any task should be permitted for manager"
    assert t.is_permitted_for?( admin   ), "Any task should be permitted for admin"

    refute t.can_be_modified_by?( u       ), "Task should not be mutable by normal user"
    refute t.can_be_modified_by?( manager ), "Inactive task should not be mutable by manager"
    assert t.can_be_modified_by?( admin   ), "Any task should be mutable by admin"
  end

  # =========================================================================
  # Test some general utility methods.
  # =========================================================================

  test "06 utility methods" do

    # Augmented title methods shouldn't crash for different project
    # and customer assignments.

    t = Task.new
    t.title = "New task"
    assert_nothing_raised( "Method should never raise exceptions" ) {
      t.augmented_title
    }

    p = Project.first
    c = p.customer

    p.customer = nil
    p.save!

    t.project = p
    assert_nothing_raised( "Method should never raise exceptions" ) {
      t.augmented_title
    }

    p.customer = c
    p.save!

    t.project = p
    assert_nothing_raised( "Method should never raise exceptions" ) {
      t.augmented_title
    }

    Task.all do | t |
      assert_nothing_raised( "Method should never raise exceptions (see task ID #{ t.id })" ) {
        t.augmented_title
      }
    end

    # Task sorting by augmented title should never crash either.

    assert_nothing_raised( "Method should never raise exceptions" ) {
      Task.sort_by_augmented_title( Task.all )
    }

    # Full with-side-effects update.

    u = User.find( 14 )
    t = u.tasks.first
    u.control_panel.tasks = [ t ]
    u.reload
    assert u.control_panel.tasks.include?( t ), "User control panel task addition failed"

    assert_nothing_raised( "Side effects update failed" ) do
      Task.transaction do
        t.update_with_side_effects!( :active => false )
      end
    end

    refute u.tasks.include?( t ), "User task list still includes deactivated task"
    refute u.control_panel.tasks.include?( t ), "User control panel task list still includes deactivated task"
  end

  # =========================================================================
  # Test hour counting methods. These are obviously important tests, though
  # individual Task hour counting stuff is usually done just for individual
  # views (e.g. "show task") - report generation uses a different engine as
  # it has to cope with much larger aggregate operations.
  # =========================================================================

  test "07 hour counting" do

    # Via the console, I enumerated all tasks with non-zero not-committed
    # hours, sorted by maximum total hours and ended up with a task that
    # had the largest number of booked hours, with some not committed. This
    # is thus an "interesting" task for maths tests.

    t = Task.find( 230 )

    # ...(noting that 1505.75 = 1398.75 + 107.0)...

    assert_equal BigDecimal.new( "3052.25" ), t.total_worked,         "Unexpected total worked hours"
    assert_equal BigDecimal.new(  "446.5"  ), t.not_committed_worked, "Unexpected not-committed hours"
    assert_equal BigDecimal.new( "2605.75" ), t.committed_worked,     "Unexpected committed hours"

    # Test the range-based calculations.

    wp      = t.work_packets.order( 'date' => :asc )
    wpstart = wp.first
    wpend   = wp.last

    # Full range, all users

    result = t.sum_hours_over_range( wpstart.date..wpend.date )

    assert_equal BigDecimal.new(  "446.5"  ), result[ :not_committed ], "Unexpected not-committed full range hours"
    assert_equal BigDecimal.new( "2605.75" ), result[ :committed     ], "Unexpected committed full range hours"

    # Test user filtering

    result = t.sum_hours_over_range( wpstart.date..wpend.date, User.first )

    assert_equal BigDecimal.new(    "0.0" ), result[ :not_committed ], "Unexpected per-user not-committed full range hours"
    assert_equal BigDecimal.new( "1370.5" ), result[ :committed     ], "Unexpected per-user committed full range hours"

    result = t.sum_hours_over_range( wpstart.date..wpend.date, t.users.last )

    assert_equal BigDecimal.new( "168.0" ), result[ :not_committed ], "Unexpected per-user not-committed full range hours"
    assert_equal BigDecimal.new(   "0.0" ), result[ :committed     ], "Unexpected per-user committed full range hours"

    # Test range splitting. Start with a known date that's sensitive.
    # If the range the database actually retrieves is greater by a day
    # either way (inclusive/exclusive problems) then the result will
    # differ.

    d      = Date.parse("2013-04-02")
    result = t.sum_hours_over_range( d..d )

    assert_equal BigDecimal.new( "7.75" ), result[ :not_committed ], "Unexpected per-user not-committed partial range hours"
    assert_equal BigDecimal.new( "7.5"  ), result[ :committed     ], "Unexpected per-user committed partial range hours"

    # Likewise if the range is *less* than less than / more than a day
    # in the ranges specified, the result will differ.

    result = t.sum_hours_over_range( d - 1.day..d )

    assert_equal BigDecimal.new( "15.75" ), result[ :not_committed ], "Unexpected per-user not-committed partial range hours"
    assert_equal BigDecimal.new( "22.5"  ), result[ :committed     ], "Unexpected per-user committed partial range hours"

    result = t.sum_hours_over_range( d..d + 1.day )

    assert_equal BigDecimal.new(  "9.75" ), result[ :not_committed ], "Unexpected per-user not-committed partial range hours"
    assert_equal BigDecimal.new( "15.0"  ), result[ :committed     ], "Unexpected per-user committed partial range hours"

    # A wider range; first narrow down to non-zero work packets only.

    wp      = t.work_packets.order( 'date' => :asc ).where( "worked_hours > 0" )
    wpstart = wp.first
    wpend   = wp.last

    # This should give the same answer as before.

    result = t.sum_hours_over_range( wpstart.date..wpend.date )

    assert_equal BigDecimal.new(  "446.5"  ), result[ :not_committed ], "Unexpected not-committed full range hours"
    assert_equal BigDecimal.new( "2605.75" ), result[ :committed     ], "Unexpected committed full range hours"

    # Again, limit slightly and check constraints still work.

    result = t.sum_hours_over_range( wpstart.date + 1.day..wpend.date - 1.day )

    assert_equal BigDecimal.new(  "446.5"  ), result[ :not_committed ], "Unexpected not-committed full range hours"
    assert_equal BigDecimal.new( "2589.75" ), result[ :committed     ], "Unexpected committed full range hours"

  end
end
