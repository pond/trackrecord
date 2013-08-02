class PopulateSavedReportRangeCaches < ActiveRecord::Migration
  def up
    SavedReport.find_each do | report |
      report.generate_report( true ) # Forces report generation, updates cached ranges in passing
    end
  end

  def down
    SavedReport.find_each do | report |
      report.range_start_cache = nil
      report.range_end_cache   = nil
      report.save!
    end
  end
end
