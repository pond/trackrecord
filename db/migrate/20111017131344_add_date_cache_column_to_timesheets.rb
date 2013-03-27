class AddDateCacheColumnToTimesheets < ActiveRecord::Migration
  def up
    add_column :timesheets, :start_day_cache, :datetime

    # Update the cache column value in all existing records. Validations must
    # be bypassed when saving records as timesheets may include e.g. tasks
    # which have been made inactive since the timesheet was last saved. With
    # normal validations, timesheets cannot be saved when they refer to
    # inactive tasks, projects or customers. We also don't want to use simple
    # save methods as these will disturb the last updated and committed dates
    # in existing timesheets. Hence, the odd use of "update_all".

    Timesheet.transaction do
      Timesheet.find_each do | timesheet |

        start_day_cache = timesheet.date_for(
          TimesheetRow::FIRST_DAY,
          true # Return as a Date rather than a String
        )

        Timesheet.update_all(
          { :start_day_cache => start_day_cache },
          { :id              => timesheet       }
        )
      end
    end
  end

  def down
    remove_column :timesheets, :start_day_cache
  end
end
