class CreateTasks < ActiveRecord::Migration
  def self.up
    create_table :tasks do | t |

      # IF YOU ADD TO THIS LIST and you don't want the column to be
      # available for mass-assignment, make sure you add the column
      # name to the attr_protected list in the model file. See the
      # model file comments for why attr_accessible isn't used.

      t.belongs_to :project
      t.boolean    :active,   :null => false, :default => true
      t.string     :title,    :null => false
      t.string     :code
      t.text       :description
      t.decimal    :duration, :null => false

      t.timestamps            :null => false

    end
  end

  def self.down
    drop_table :tasks
  end
end
