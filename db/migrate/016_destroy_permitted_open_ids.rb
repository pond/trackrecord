class DestroyPermittedOpenIds < ActiveRecord::Migration
  def self.up
    # In later revisions of TrackRecord this table is removed in favour
    # of up-front user account creation by the administrator.

    drop_table :permitted_open_ids
  end

  def self.down
    create_table :permitted_open_ids do | t |
      t.text :identity_url, :null => false
      t.timestamps
    end

    # Try to rebuild the table based on current users listed in the
    # database.

    User.find( :all ).each do | user |
      poid = PermittedOpenId.new
      poid.identity_url = user.identity_url
      poid.save!
    end
  end
end
