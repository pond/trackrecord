########################################################################
# File::    db_dump_reports_for_tests.rake
# (C)::     Hipposoft 2013
#
# Purpose:: Dump generated reports to JSON for comparison purposes
#           inside tests. Clearly, there is a presumption that the
#           data created is is correct - that the current database
#           and TrackRecord report generator will produce correct
#           results.
# ----------------------------------------------------------------------
#           25-Sep-2013 (ADH): Created.
########################################################################

namespace :db do
  task :dump_reports_for_tests => :environment do

    puts
    puts "=" * 66
    puts "WARNING: YAML encoder bugs"
    puts "=" * 66
    puts
    puts "You may need to run this more than once, for specific reports."
    puts
    puts "First run: RAILS_ENV=test rake db:dump_reports_for_tests"
    puts "Then run:  rake test TEST=test/unit/saved_report_test.rb"
    puts
    puts "It is very likely that one or more of the tests will fail due to"
    puts "the erorr 'Section title differs'. This error is expected and is"
    puts "happening because of YAML random corruption in the YAML dump made"
    puts "here. It affects different reports every time this script is run,"
    puts "so 'feels like' an uninitialised variable problem in some native"
    puts "'C' code deep in the bowels of Ruby/Rails/YAML/psych."
    puts
    puts "The ID of the SavedReport that is causing trouble is in the error"
    puts "message, e.g. \"Report 55, task 750: Section title differs\" - the"
    puts "ID is 55."
    puts
    puts "Take note of the ID in the failing test(s), then edit the Rake"
    puts "task in 'lib/tasks/db_dump_reports_for_tests.rake' and get it to"
    puts "regenerate the YAML dumps for just the affected saved reports. In"
    puts "so doing, the pseudo-random bug will probably not strike and now"
    puts "all tests for all saved reports should pass, though it's possible"
    puts "that you may need to go 'around the loop' more than once."
    puts
    puts "Only section title differences are expected - nothing else - any"
    puts "other test failures at all are unexpected and need invesigation."
    puts
    puts "Once you can at least verify that same-database-same-data reports"
    puts "all pass, you can check in any updated comparison data and/or run"
    puts "the test suite on top of different database engines."
    puts
    puts "=" * 66
    puts
    puts "Have #{ SavedReport.count } reports to process"
    puts

    count = 1
    base  = File.join( Rails.root, "test", "comparison_data", "saved_reports" )

    # Comparison of entire SavedReport objects isn't necessary (separate
    # tests, similar to the other normal model tests, cover those). Trying
    # to compare entire generated TrackRecordReport::Report instances
    # within a SavedReport doesn't work either, because different
    # databases use different grouping mechanisms (e.g. integers, strings,
    # fast generation on PostgreSQL vs slow generation for generic SQL).
    # Instead all we can do is manually compare rows/columns via the usual
    # official iterator API the Report provides and make sure values are
    # the same. Thus this data dump task aims to preserve that information
    # but doesn't care much about anything else.

    SavedReport.find_each do | sr |
      puts "#{ count }: SavedReport ID #{ sr.id }..."

      path = File.join( base, "#{ sr.id }.yaml.gz" )
      r    = sr.generate_report().compile()

      # Can't just dump "r" as it contains a Proc, but one we don't need
      # after compilation (at least at the time of writing). This is good
      # enough to be able to compare generated numbers in tests.

      r.frequency_data[ :date_to_key ] = nil
      str = YAML::dump( r )

      wio = File.new( path, "wb" )
      w_gz = Zlib::GzipWriter.new( wio )
      w_gz.write( str )
      w_gz.close

      count += 1
    end

    puts
    puts "...finished."
  end
end
