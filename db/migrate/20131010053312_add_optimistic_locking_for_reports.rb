# Originally didn't think I'd want optimistic locking on saved
# report objects. The intention was to only let users modify their
# own items, but in the end admins were allowed to edit everything
# as usual for general consistency. There's a small but non-zero
# chance of a user and admin concurrently editing the same report,
# so a versioning column is required.
#
# This is based on "015_add_optimistic_locking.rb".

class AddOptimisticLockingForReports < ActiveRecord::Migration
  def self.up
    add_column :saved_reports, :lock_version, :integer, :default => 0

    # Update existing data

    ActiveRecord::Base.lock_optimistically = false

    SavedReport.reset_column_information
    SavedReport.all.each do | obj |
      obj.lock_version = 0
      obj.save!
    end

    ActiveRecord::Base.lock_optimistically = true
  end

  def self.down
    remove_column :saved_reports, :lock_version
  end
end