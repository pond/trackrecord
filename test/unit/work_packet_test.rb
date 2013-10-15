require File.dirname(__FILE__) + '/../test_helper'

class WorkPacketTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 46368, WorkPacket.count, "Wrong work packet count (A)"
  end

  # =========================================================================
  # More complicated data checks.
  # =========================================================================

  test "02 make sure work packet metrics look sane" do
    assert_equal 13141, WorkPacket.significant.count, "Wrong non-zero work packet count (A)"

    WorkPacket.find_each do | wp |
      assert_equal BigDecimal.new( wp.worked_hours.to_f.to_s ), wp.worked_hours, "Unexpected work hours format for packet #{ wp.id }"
      refute wp.worked_hours < 0, "Negative worked hours for packet #{ wp.id }"
      refute wp.worked_hours > 24, "Too high worked hours for packet #{ wp.id }"
      refute_nil wp.timesheet_row, "No timesheet row for packet #{ wp.id }"
      assert wp.date.year >= 2006, "Too low a year for packet #{ wp.id }"
      assert wp.date.year <= 2014, "Too high a year for packet #{ wp.id }"
      refute wp.day_number < 0, "Negative day number for packet #{ wp.id }"
      refute wp.day_number > 6, "Too high a day number for packet #{ wp.id }"
    end
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "03 basic model paranoia" do
    wp = WorkPacket.new
    refute wp.save, "A blank Work Packet was saved"

    wp.timesheet_row = TimesheetRow.first
    wp.day_number = 0

    wp.worked_hours = "foo"
    refute wp.save, "An invalid Work Packet was saved (A)"
    wp.worked_hours = -2
    refute wp.save, "An invalid Work Packet was saved (B)"
    wp.worked_hours = 25
    refute wp.save, "An invalid Work Packet was saved (C)"

    wp.worked_hours = 7.5

    wp.day_number = -2
    refute wp.save, "An invalid Work Packet was saved (D)"
    wp.day_number = 9
    refute wp.save, "An invalid Work Packet was saved (E)"

    wp.day_number = "foo"
    assert_equal 0, wp.day_number, "Work packet day number was not coerced as expected (A)"
    wp.day_number = 5.9
    assert_equal 5, wp.day_number, "Work packet day number was not coerced as expected (B)"

    wp.day_number = 0
    assert wp.save, "A valid Work Packet could not be saved"

    refute_nil wp.date, "A saved Work Packet was not assigned a date"

    assert_equal 46369, WorkPacket.count, "Wrong work packet count (B)"
    assert_equal 13142, WorkPacket.significant.count, "Wrong non-zero work packet count (B)"

    wp.destroy

    assert_equal 46368, WorkPacket.count, "Wrong work packet count (C)"
    assert_equal 13141, WorkPacket.significant.count, "Wrong non-zero work packet count (C)"
  end

  # =========================================================================
  # Exercise the various "find by" class methods.
  # =========================================================================

  test "04 retrieval utility methods" do
    first = WorkPacket.find_earliest_by_tasks()
    assert_equal "11873", first.id.to_s, "First work packet differs from expected result (A)"

    last = WorkPacket.find_latest_by_tasks()
    assert_equal "20517", last.id.to_s, "Last work packet differs from expected result (A)"

    first = WorkPacket.find_first_by_tasks_and_order( [], 'worked_hours DESC, created_at ASC' )
    assert_equal "45587", first.id.to_s, "First work packet differs from expected result (B)"

    tasks = [ 93, 36, 124, 27 ] # Pretty much at random...

    first = WorkPacket.find_earliest_by_tasks( tasks )
    assert_equal "31642", first.id.to_s, "First work packet differs from expected result (C)"

    last = WorkPacket.find_latest_by_tasks( tasks )
    assert_equal "47488", last.id.to_s, "Last work packet differs from expected result (B)"

    first = WorkPacket.find_first_by_tasks_and_order( tasks, 'worked_hours DESC, created_at ASC' )
    assert_equal "31643", first.id.to_s, "First work packet differs from expected result (D)"
  end
end
