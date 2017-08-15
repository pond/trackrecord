class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do | t |

      # IF YOU ADD TO THIS LIST and you don't want the column to be
      # available for mass-assignment, make sure you add the column
      # name to the attr_protected list in the model file. See the
      # model file comments for why attr_accessible isn't used.

      t.text     :identity_url, :null => false
      t.text     :name,         :null => false
      t.text     :email,        :null => false
      t.string   :code
      t.string   :user_type,    :null => false
      t.boolean  :active,       :null => false, :default => true
      t.datetime :last_committed

      t.timestamps              :null => false

    end
  end

  def self.down
    drop_table :users
  end
end
