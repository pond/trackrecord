class AddNewReportDateRangeTypes < ActiveRecord::Migration
  def change
    # See 20111013142252_add_saved_reports_support.rb

    add_column :saved_reports, :range_one_month, :string, :limit => 7
    add_column :saved_reports, :range_one_week,  :string, :limit => 7
  end
end
