########################################################################
# File::    can_database_do_fast_reports.rb
# (C)::     Hipposoft 2013
#
# Purpose:: See if we're using PostgreSQL. If not - problem for reports,
#           especially weekly reports. Please see doc/README_FOR_APP.
# ----------------------------------------------------------------------
#           15-Aug-2013 (ADH): Created.
########################################################################

# http://stackoverflow.com/questions/1628608/how-do-i-check-the-database-type-in-a-rails-migration

adapter_type = ActiveRecord::Base.connection.adapter_name.downcase.to_sym

# Please see doc/README_FOR_APP for details, as well as the documentation
# for TrackRecordReport::FREQUENCY. If you think you have modified that
# constant appropriately for your database, you can force the constant
# below to take a value of 'true'.
#
SLOW_DATABASE_ALTERATIVE = ( adapter_type != :postgresql )
