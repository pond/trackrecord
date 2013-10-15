require File.dirname(__FILE__) + '/../test_helper'

class TimesheetRowTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 6624, TimesheetRow.count, "Wrong timesheet row count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "02 basic model paranoia" do
    tr = TimesheetRow.new
    refute tr.save, "A blank timesheet row was saved"

    tr.timesheet = User.admins.first.timesheets.first
    tr.task = Task.active.first

    assert tr.save, "Could not save a valid timesheet row"
    assert tr.timesheet.timesheet_rows.last == tr, "Timesheet row was at unexpected position (A)"

    tr.move_to_top
    tr.reload
    tr.timesheet.reload
    assert tr.timesheet.timesheet_rows.first == tr, "Timesheet row was at unexpected position (B)"

    TimesheetRow::DAY_ORDER.each_with_index do | day, index |
      assert_equal day, tr.work_packets[ index ].day_number, "Row's work packet has wrong day number"
    end

    assert_equal 0, tr.row_sum(), "Expected zero row sum, didn't get it"

    tr.work_packets.each_with_index do | wp, index |
      wp.worked_hours = index + 1
      wp.save!
    end

    assert_equal 28, tr.row_sum(), "Expected a certain row sum, didn't get it"

    # Inactive task prohibition

    tr.task = Task.inactive.first
    refute tr.save, "Shouldn't be able to save a row associated with an inactive task"

    tr.task = Task.active.first
    assert tr.save, "Couldn't save a valid timesheet row"

    # Reassign to a restricted user and assign a task the user has
    # not been permitted to see. Reassigning a row to a new timesheet
    # like this is not possible through the UI and there's no code at
    # the time of writing to handle it "properly" (including making
    # sure the acts-as-list position is updated); we don't care; this
    # is thus not checked.

    u = User.find( 14 )
    tr.timesheet = u.timesheets.first
    tr.task = ( Task.active - u.tasks ).first
    refute tr.save, "Shouldn't be able to save a row associated with a prohibited task"

    tr.task = u.tasks.first
    assert tr.save, "Should be able to save a row associated with an allowed task"

    # Check the work packets get deleted with the row

    before = WorkPacket.count
    tr.destroy
    after = WorkPacket.count

    assert_equal 7, before - after, "Work packet count did not drop as expected when a row was deleted"
  end
end
