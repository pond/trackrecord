class AddOptimisticLocking < ActiveRecord::Migration
  def self.up
    add_column :timesheets, :lock_version, :integer, :default => 0
    add_column :customers,  :lock_version, :integer, :default => 0
    add_column :projects,   :lock_version, :integer, :default => 0
    add_column :tasks,      :lock_version, :integer, :default => 0
    add_column :users,      :lock_version, :integer, :default => 0

    # Update existing data

    ActiveRecord::Base.lock_optimistically = false

    [ Timesheet, Customer, Project, Task, User ].each do | cls |
      cls.reset_column_information
      cls.find( :all ).each do | obj |
        obj.lock_version = 0
        obj.save!
      end
    end

    ActiveRecord::Base.lock_optimistically = true
  end

  def self.down
    remove_column :timesheets, :lock_version
    remove_column :customers,  :lock_version
    remove_column :projects,   :lock_version
    remove_column :tasks,      :lock_version
    remove_column :users,      :lock_version
  end
end
