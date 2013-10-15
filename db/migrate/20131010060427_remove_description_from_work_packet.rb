# See also "003_create_work_packets.rb".
#
# Note the migration is not truly reversible since it removes a column,
# thus discarding data. Since TrackRecord never puts anything in there,
# though, this is OK. If third parties are using patched variants with
# some use for individual work packet descriptions, they'll need to
# comment out the add/remove calls in the code below.
#
# It's conceivable of course that this field may need to be re-added in
# future but it hasn't been required in years and right now just bloats
# the database.

class RemoveDescriptionFromWorkPacket < ActiveRecord::Migration
  def up
    remove_column :work_packets, :description
  end

  def down
    add_column :work_packets, :description, :text
  end
end
