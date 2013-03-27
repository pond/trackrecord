########################################################################
# File::    rangeable.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Base class for objects which have a 'used range' defined by
#           an oldest and newest item in the database.
# ----------------------------------------------------------------------
#           26-Mar-2013 (ADH): Created.
########################################################################

class Rangeable < ActiveRecord::Base

  self.abstract_class = true

  # Return a range of years used by all instances. Optionally pass 'true'
  # if you want an actual Date object range rather than just a year range.
  #
  # Derived classes must set USED_RANGE_COLUMN to the column for sorting;
  # e.g. "created_at". See also "appctrl_search_range_sql" and elsewhere.
  #
  def self.used_range( accurate = false )

    # May get nothing back from 'first' if there are no instances of the
    # record for this model at all in the database, so use 'try' to get
    # the 'created_at' value or, if there are no objects, 'nil'.

    first = self.unscoped.order( "#{ self::USED_RANGE_COLUMN } ASC"  ).first.try( :created_at )
    last  = self.unscoped.order( "#{ self::USED_RANGE_COLUMN } DESC" ).first.try( :created_at )

    first = last = Date.current if ( first.nil? ) # No instances of this object in database

    if accurate
      ( first.to_date )..( last.to_date )
    else
      ( first.year )..( last.year )
    end
  end

end