class AddAutoSortingToTimesheets < ActiveRecord::Migration
  def change
    add_column :timesheets, :auto_sort, :string, :limit => Timesheet::AUTO_SORT_FIELD_LIMIT
  end
end
