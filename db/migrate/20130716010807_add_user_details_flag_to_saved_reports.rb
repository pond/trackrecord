class AddUserDetailsFlagToSavedReports < ActiveRecord::Migration
  def change
    add_column :saved_reports, :user_details, :boolean
  end
end
