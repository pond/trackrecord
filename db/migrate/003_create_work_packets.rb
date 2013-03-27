class CreateWorkPackets < ActiveRecord::Migration
  def self.up
    create_table :work_packets do | t |

      t.belongs_to :timesheet_row, :null => false

      t.integer    :day_number,    :null => false
      t.decimal    :worked_hours,  :null => false
      t.text       :description
      t.datetime   :date,          :null => false

      t.timestamps

    end
  end

  def self.down
    drop_table :work_packets
  end
end
