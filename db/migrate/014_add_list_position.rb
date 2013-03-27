class AddListPosition < ActiveRecord::Migration
  def self.up
    add_column :timesheet_rows, :position, :integer

    # Update existing data

    TimesheetRow.reset_column_information
    Timesheet.find_each do | timesheet |
      timesheet.timesheet_rows.each_with_index do | row, index |
        row.position = index + 1
        row.save!
      end
    end
  end

  def self.down
    remove_column :timesheet_rows, :position
  end
end
