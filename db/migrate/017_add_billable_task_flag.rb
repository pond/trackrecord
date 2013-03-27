class AddBillableTaskFlag < ActiveRecord::Migration
  def self.up

    # Change 'true' to 'false' in the following line of code if you want new
    # tasks to be set to non-billable by default.

    add_column :tasks, :billable, :boolean, :default => true

    # Update existing data. For currently known deployments there are far more
    # billable tasks than non-billable, so at least in those cases, it makes
    # sense to set the flag to 'true' by default. If your deployment differs
    # and you're lucky enough to read this in time then you can change the
    # assignment to "task.billable" below; else you could update all task
    # objects manually after the migration at the console prompt (issue "ruby
    # script/console" from the TrackRecord root directory) with code along the
    # lines of:
    #
    #   Task.all.each { |task| task.billable = true; task.save! }

    Task.reset_column_information
    Task.find_each do | task |
      task.billable = true
      task.save!
    end
  end

  def self.down
    remove_column :tasks, :billable
  end
end
