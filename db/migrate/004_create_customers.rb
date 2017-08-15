class CreateCustomers < ActiveRecord::Migration
  def self.up
    create_table :customers do | t |

      # IF YOU ADD TO THIS LIST and you don't want the column to be
      # available for mass-assignment, make sure you add the column
      # name to the attr_protected list in the model file. See the
      # model file comments for why attr_accessible isn't used.

      t.boolean :active, :null => false, :default => true
      t.string  :title,  :null => false
      t.string  :code
      t.text    :description

      t.timestamps :null => false

    end
  end

  def self.down
    drop_table :customers
  end
end
