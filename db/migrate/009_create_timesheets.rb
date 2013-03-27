class CreateTimesheets < ActiveRecord::Migration
  def self.up
    create_table :timesheets do | t |

      # IF YOU ADD TO THIS LIST and you don't want the column to be
      # available for mass-assignment, make sure you add the column
      # name to the attr_protected list in the model file. See the
      # model file comments for why attr_accessible isn't used.

      t.belongs_to :user,         :null => false

      t.integer    :week_number,  :null => false
      t.integer    :year,         :null => false
      t.text       :description
      t.boolean    :committed,    :null => false, :default => false
      t.datetime   :committed_at

      t.timestamps

    end
  end

  def self.down
    drop_table :timesheets
  end
end
