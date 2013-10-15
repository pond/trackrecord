# Work Packets have dates but these were originally created as DateTime
# columns. This causes edge case database issues for SQLite when using
# ranges to try and select work packets based on date. A date such as
# "2012-02-04" does not match "2012-02-04 00:00:00.000000 UTC" for some
# queries.
#
# The Work Packet date cache column can only ever have a date value as
# a work packet describes a full day of work on a given task, so the
# time component is redundant. Removing it solves edge case issues.

class ChangeWorkPacketDateColumnType < ActiveRecord::Migration
  def up
    change_column :work_packets, :date, :date
  end

  def down
    change_column :work_packets, :date, :datetime
  end
end
