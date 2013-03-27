class CreateControlPanelsTasks < ActiveRecord::Migration
  def self.up
    create_table :control_panels_tasks, :id => false do | t |

      t.integer :control_panel_id
      t.integer :task_id

    end

    add_index :control_panels_tasks, [ :task_id, :control_panel_id ]
    add_index :control_panels_tasks, [ :control_panel_id           ]
  end

  def self.down
    drop_table :control_panels_tasks
  end
end
