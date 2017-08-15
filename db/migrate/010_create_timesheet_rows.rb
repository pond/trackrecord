class CreateTimesheetRows < ActiveRecord::Migration
  def self.up
    create_table :timesheet_rows do | t |

      t.belongs_to :timesheet, :null => false
      t.belongs_to :task,      :null => false

      t.timestamps             :null => false

    end
  end

  def self.down
    drop_table :timesheet_rows
  end
end
