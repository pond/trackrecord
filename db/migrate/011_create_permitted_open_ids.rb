class CreatePermittedOpenIds < ActiveRecord::Migration
  def self.up
    create_table :permitted_open_ids do | t |

      # In later revisions of TrackRecord this table is removed in favour
      # of up-front user account creation by the administrator.

      t.text       :identity_url, :null => false
      t.timestamps                :null => false

    end
  end

  def self.down
    drop_table :permitted_open_ids
  end
end
