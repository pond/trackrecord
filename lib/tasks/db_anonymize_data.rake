########################################################################
# File::    db_anonymize_data.rake
# (C)::     Hipposoft 2013
#
# Purpose:: Anonymize all development mode data and write test mode
#           data. Resets all item names, descriptions, dates, audit
#           trail and so-on; renumbers timesheet weeks, reorders
#           rows and fuzzes worked hours. The result is a new set of
#           data. It is not possible to reconstruct the original nor
#           computationally feasiable to discover which parts of the
#           derived data set might have come from which parts of the
#           original data set, even assuming you had access to both.
#
#           The test database should be empty and migrated to the most
#           recent version (rake db:drop, db:create, db:migrate under
#           RAILS_ENV=test first). The source development database
#           must obviously also be migrated to the most recent version
#           (rake db:migrate under RAILS_ENV=development).
#
#           Not all items in the source data set are included in the
#           destination - again this is part of the anonymisation. The
#           end result is partially random, but still has a roughly
#           human shape to it which would be hard to achieve using
#           true auto generation. On the other hand there's not much
#           point running this script for trivial source data sets as
#           you might as well just hand-create a custom test set.
# ----------------------------------------------------------------------
#           12-Sep-2013 (ADH): Created.
#           09-Oct-2013 (ADH): Heavily modified to essentially just use
#                              the source data as a template to provide
#                              a rough shape in the destination data.
########################################################################

# Note use of grouping and shuffle throughout this script to break
# associations between creation dates and original data.

# Step 1: Get a reproducable map of all data we intend to anonymise
# inside this Ruby process, using a connection to the development
# mode database.

namespace :db do
  task :anonymize_data => :environment do

    STDOUT.puts
    STDOUT.puts "=" * 72
    STDOUT.puts "Migrating constructed development data into an"
    STDOUT.puts "anonymised, randomised test set."
    STDOUT.puts
    STDOUT.puts "If anything fails, destroy and recreate the"
    STDOUT.puts "test database as contents will be inconsistent."
    STDOUT.puts
    STDOUT.puts "1. Reading basic data and constructing derived data"
    STDOUT.puts "=" * 72
    STDOUT.puts

    ActiveRecord::Base.establish_connection( "development" )

    # Keyed by source (original) object, value is destination object. There
    # is also an array 'users', 'customers' etc. which is the in-order array
    # of source objects that were processed.

    dst_users     = {}
    dst_customers = {}
    dst_projects  = {}
    dst_tasks     = {}
    dst_reports   = {}

    # Migrate users. This creates control panels in passing but we cannot
    # map those until customers, projects and tasks are migrated too.

    first_user = [ User.admins.first ]
    array = first_user +
            ( User.admins.active - first_user ).shuffle +
            User.admins.inactive.shuffle +
            User.managers.active.shuffle +
            User.managers.inactive.shuffle +
            User.restricted.active.shuffle +
            User.restricted.inactive.shuffle

    # Ignore users with less than 5 timesheets. Rather an arbitrary
    # threshold but for non-trivial data sets there's little point in
    # including near-trivial entries.

    array.reject! { | user | user.timesheets.count < 5 }

    array.each_with_index do | item, index |
      count = index + 1
      object = item.dup

      unless ( count == 1 )
        object.identity_url = "http://openid-test-#{count}.test.invalid"
        object.name = "Test user #{count}"
        object.email = "test_#{count}@test.invalid"
      end

      object.code = "UID%04d" % index
      object.last_committed = nil
      object.lock_version = 0

      dst_users[ item.id ] = {
        :dst_user    => object,
        :src_tids    => item.task_ids,
        :src_cp      => item.control_panel,
        :src_cp_tids => item.control_panel.task_ids
      }

      STDOUT.puts "#{object.class} #{index} of #{array.count} (ID #{item.id})"
    end

    users = array

    # Migrate only the tasks used in timesheet rows by the user array
    # calculated above. Associations to things like the user control panel
    # have to wait until we can switch connection to the test database and
    # start writing all new data to the test database, under a transaction.
    #
    # The ID-based hoop jumping is an optimisation over e.g. collecting all
    # user timesheets, their rows, then the associated tasks (especially
    # given the default scope on Task that eager loads associated projects
    # and customers).
    #
    # For each task, a duplicate is created with a randomised duration.
    # These duplciates may be randomly chosen for inclusion in the final
    # written data set.

    user_ids = array.map( &:id )
    timesheet_ids = Timesheet.where( :user_id => user_ids ).select( :id ).map( &:id ).uniq
    task_ids = TimesheetRow.where( :timesheet_id => timesheet_ids ).select( :task_id ).map( &:task_id ).uniq
    array = Task.find( task_ids ).shuffle
    numbers = ( 1..( array.count * 2 ) ).to_a.shuffle

    array.each_with_index do | item, index |
      count = numbers[ index * 2 ] || 0
      object = item.dup

      object.title = "Test task #{count}"
      object.description = "Description for test task #{count}"
      object.code = "TID%05d" % count
      object.duration = ( object.duration * 4 * ( ( rand() / 5 ) + 0.9 ) ).floor / 4.0 unless object.duration.zero?
      object.lock_version = 0

      dst_tasks[ item.id ] = [ object ]

      count = numbers[ index * 2 + 1 ] || 0
      object = item.dup

      object.title = "Test task #{count}"
      object.description = "Description for test task #{count}"
      object.code = "TID%05d" % count
      object.duration = rand( 10000 ) / 4.0
      object.lock_version = 0

      dst_tasks[ item.id ] << object

      STDOUT.puts "#{object.class} #{index + 1} of #{array.count} (ID #{item.id})"
    end

    tasks = array

    # Migrate only those projects referenced by tasks in the array
    # calculated above. As with tasks, duplicates are created which
    # may at random be included in the final data set.

    array = array.map( &:project ).uniq.shuffle
    numbers = ( 1..( array.count * 2 ) ).to_a.shuffle

    array.each_with_index do | item, index |
      count = numbers[ index * 2 ] || 0
      object = item.dup

      object.title = "Test project #{count}"
      object.description = "Description for test project #{count}"
      object.code = "PID%05d" % count
      object.lock_version = 0

      dst_projects[ item.id ] = [ object ]

      count = numbers[ index * 2 + 1 ] || 0
      object = item.dup

      object.title = "Test project #{count}"
      object.description = "Description for test project #{count}"
      object.code = "PID%05d" % count
      object.lock_version = 0

      dst_projects[ item.id ] << object

      STDOUT.puts "#{object.class} #{index + 1} of #{array.count} (ID #{item.id})"
    end

    projects = array

    # Migrate only those customers referenced by projects in the array
    # calculated above.

    array = array.map( &:customer ).uniq.shuffle

    array.each_with_index do | item, index |
      count = index + 1
      object = item.dup

      object.title = "Test customer #{count}"
      object.description = "Description for test customer #{count}"
      object.code = "CID%05d" % index
      object.lock_version = 0

      dst_customers[ item.id ] = object

      STDOUT.puts "#{object.class} #{count} of #{array.count} (ID #{item.id})"
    end

    customers = array

    # Migrate all reports from migrated users. The source database is assumed
    # to be loaded with rational test exercise reports already. If this is not
    # the case, just skip this migration step by altering the code below to
    # iterate over no reports ("array = reports = []").

    array = reports = SavedReport.where( :user_id => users ).all.shuffle

    array.each_with_index do | item, index |
      count = index + 1
      object = item.dup
      object.lock_version = 0

      dst_reports[ item.id ] = {
        :report => object,
        :tids   => item.active_task_ids + item.inactive_task_ids,
        :uids   => item.reportable_user_ids
      }

      STDOUT.puts "#{object.class} #{count} of #{array.count} (ID #{item.id})"
    end

    STDOUT.puts
    STDOUT.puts "=" * 72
    STDOUT.puts "2. Writing basic constructing derived data"
    STDOUT.puts "=" * 72
    STDOUT.puts

    ActiveRecord::Base.establish_connection( "test" )

    # Keyed by destination object once it has an ID, value is source object

    User.transaction do

      customers.each_with_index do | customer, index |
        object = dst_customers[ customer.id ]

        raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save

        STDOUT.puts "Saved #{object.class} #{index + 1} of #{customers.count} (ID #{object.id})"
      end

      projects.each_with_index do | project, index |
        object          = dst_projects[ project.id ][ 0 ]
        object.customer = dst_customers[ project.customer_id ]

        raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save

        if ( rand > 0.8 )
          object          = dst_projects[ project.id ][ 1 ]
          object.customer = dst_customers[ project.customer_id ]

          raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save
        end

        STDOUT.puts "Saved #{object.class} #{index + 1} of #{projects.count} (ID #{object.id})"
      end

      tasks.each_with_index do | task, index |
        object         = dst_tasks[ task.id ][ 0 ]
        object.project = dst_projects[ task.project_id ][ 0 ]

        raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save

        if ( rand > 0.6 )
          object         = dst_tasks[ task.id ][ 1 ]
          object.project = dst_projects[ task.project_id ][ 0 ]

          raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save
        end

        STDOUT.puts "Saved #{object.class} #{index + 1} of #{tasks.count} (ID #{object.id})"
      end

      users.each_with_index do | user, index |
        hash   = dst_users[ user.id ]
        object = hash[ :dst_user ]

        raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save

        dst_user_tasks = []

        hash[ :src_tids ].each do | tid |
          dst_user_tasks << dst_tasks[ tid ][ 0 ]
        end

        object.tasks = dst_user_tasks.compact.shuffle

        src_cp = hash[ :src_cp ]
        dst_cp = object.control_panel

        dst_cp.project  = dst_projects[ src_cp.project_id ].try( :[], 0 )
        dst_cp.customer = dst_customers[ src_cp.customer_id ]

        dst_cp_tasks = []

        hash[ :src_cp_tids ].each do | cp_tid |
          dst_cp_tasks << dst_tasks[ cp_tid ][ 0 ]
        end

        dst_cp.tasks = dst_cp_tasks.compact.shuffle

        raise "Couldn't save Control Panel: #{dst_cp.errors.messages}" unless dst_cp.save

        STDOUT.puts "Saved #{object.class} #{index + 1} of #{users.count} (ID #{object.id})"
      end

      reports.each_with_index do | report, index |
        hash   = dst_reports[ report.id ]
        object = hash[ :report ]

        raise "Couldn't save #{ object.class }:\n#{ object.errors.messages }\n\n@#{ object.inspect }\n" unless object.save

        dst_report_tasks = []

        hash[ :tids ].each do | tid |
          dst_report_tasks << dst_tasks[ tid ].try( :[], 0 )
        end

        dst_report_tasks      = dst_report_tasks.compact.shuffle
        object.active_tasks   = dst_report_tasks.select { | t |   t.active }
        object.inactive_tasks = dst_report_tasks.select { | t | ! t.active }

        dst_report_users = []

        hash[ :uids ].each do | uid |
          dst_report_users << dst_users[ uid ].try( :[], :dst_user )
        end

        object.reportable_users = dst_report_users.compact.shuffle

        STDOUT.puts "Saved #{object.class} #{index + 1} of #{reports.count} (ID #{object.id})"
      end
    end

    STDOUT.puts
    STDOUT.puts "=" * 72
    STDOUT.puts "3. Reading timesheet data"
    STDOUT.puts "=" * 72
    STDOUT.puts

    ActiveRecord::Base.establish_connection( "development" )

    # This runs slowly and no amount of attempting to enforce eager
    # loading with "includes(...)" makes any difference. Even though
    # the timesheet query, for example, will load rows and work
    # packets, the inner loops still then re-run the smaller queries
    # for rows or work packets anyway.
    #
    # So I'm missing something here, but efficiency herein isn't all
    # that important so it isn't worth any more effort right now.

    src_timesheets = {}

    users.each_with_index do | src_user, index |
      STDOUT.puts "Reading #{src_user.timesheets.count} timesheets for user #{index + 1} of #{users.count}"

      src_user.timesheets.all.shuffle.each do | src_timesheet |
        next if src_timesheet.total_sum == 0

        hash = {
          :timesheet => src_timesheet,
          :rows      => []
        }

        src_timesheet.timesheet_rows.all.each do | src_timesheet_row |
          hash[ :rows ] << {
            :row => src_timesheet_row,
            :work_packets => src_timesheet_row.work_packets.all
          }
        end

        hash[ :rows ].shuffle!

        src_timesheets[ src_user.id ] ||= []
        src_timesheets[ src_user.id ] << hash
      end
    end

    STDOUT.puts
    STDOUT.puts "=" * 72
    STDOUT.puts "4. Writing similar form timesheet data"
    STDOUT.puts "=" * 72
    STDOUT.puts

    ActiveRecord::Base.establish_connection( "test" )

    scrambled_weeks = (1..53).to_a.shuffle

    User.transaction do

      users.each_with_index do | src_user, index |
        STDOUT.puts "Writing #{src_timesheets[ src_user.id ].count} timesheets for user #{index + 1} of #{users.count}"

        src_timesheets[ src_user.id ].each do | hash |

          src_timesheet       = hash[ :timesheet ]
          object              = Timesheet.new
          object.user         = dst_users[ src_user.id ][ :dst_user ]
          object.week_number  = scrambled_weeks[ src_timesheet.week_number - 1 ]
          object.year         = src_timesheet.year
          object.committed    = src_timesheet.committed
          object.committed_at = Time.now if src_timesheet.committed
          object.description  = "Description for test timesheet #{index + 1}"
          object.auto_sort    = src_timesheet.auto_sort
          object.lock_version = 0

          raise "Couldn't save Timesheet: #{object.errors.messages}" unless object.save

          object.timesheet_rows.destroy_all

          src_rows            = hash[ :rows ]
          scrambled_positions = (1..src_rows.count).to_a.shuffle
          max_halfhours       = 48 / src_rows.count unless src_rows.count.zero?

          src_rows.each_with_index do | src_row_hash, index |
            src_row = src_row_hash[ :row          ]
            src_wps = src_row_hash[ :work_packets ]

            new_row           = TimesheetRow.new
            new_row.timesheet = object
            new_row.task      = dst_tasks[ src_row.task_id ][ 0 ]
            new_row.position  = scrambled_positions[ index ]

            raise "Couldn't save TimesheetRow: #{new_row.errors.messages}" unless new_row.save( :validate => false ) # Can't validate as some tasks may be (correctly) inactive

            src_wps.each_with_index do | src_wp, index |
              new_wp = new_row.work_packets[ index ]

              # 10% ish chance that zero packets end up between 1 and 8 quarter
              # hours. 80% ish chance that other packets get a fuzzed value
              # based around the actual work packet total. 20% ish chance that
              # the remainder get a random assignment.

              if ( src_wp.worked_hours.zero? )
                dst_qhours = rand() > 0.9 ? rand( 1..8 ) : 0
              elsif rand() > 0.2
                dst_qhours = ( src_wp.worked_hours * 4 * ( ( rand() / 5 ) + 0.9 ) ).floor
              else
                dst_qhours = rand( 1..16 )
              end

              new_wp.worked_hours = dst_qhours / 4.0
              raise "Couldn't update WorkPacket #{new_wp.id}: #{new_wp.errors.messages}" unless new_wp.save( :validate => false )
            end
          end # timesheet.timesheet_rows.each...
        end   # user.timesheets.each...
      end     # users.each_with_index...

    end       # User.transaction...

  end # task...do...
end   # namespace...do...
