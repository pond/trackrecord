class CreateControlPanels < ActiveRecord::Migration
  def self.up
    create_table :control_panels do |t|
      t.belongs_to :user
      t.belongs_to :project
      t.belongs_to :customer

      t.timestamps :null => false
    end
  end

  def self.down
    drop_table :control_panels
  end
end
