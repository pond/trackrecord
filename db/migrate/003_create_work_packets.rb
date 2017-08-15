# See also "20131010060427_remove_description_from_work_packet.rb".
#
# The description field is never used and removed by the later migration, but
# is kept here for historical consistency and existing user data migrations.

class CreateWorkPackets < ActiveRecord::Migration
  def self.up
    create_table :work_packets do | t |

      t.belongs_to :timesheet_row, :null => false

      t.integer    :day_number,    :null => false
      t.decimal    :worked_hours,  :null => false
      t.text       :description
      t.datetime   :date,          :null => false

      t.timestamps                 :null => false

    end
  end

  def self.down
    drop_table :work_packets
  end
end
