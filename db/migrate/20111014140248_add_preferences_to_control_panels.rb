class AddPreferencesToControlPanels < ActiveRecord::Migration
  def up
    add_column :control_panels, :preferences, :text
  end

  def down
    remove_column :control_panels, :preferences
  end
end
