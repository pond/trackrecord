########################################################################
# File::    extend_acts_as_audited_model.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Extend acts_as_audited's Audit model to include constants
#           used by TrackRecord's shared list view code.
# ----------------------------------------------------------------------
#           26-Jun-2008 (ADH): Created.
#           22-Mar-2013 (ADH): Updated for Acts As Audited 3 / Rails 3.
########################################################################

module Audited
  module Adapters
    module ActiveRecord
      class Audit

        # Define default sort order for caller convenience

        DEFAULT_SORT_COLUMN    = 'created_at'
        DEFAULT_SORT_DIRECTION = 'DESC'
        DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

        USED_RANGE_COLUMN      = 'created_at'

        # Return a range of years used by all instances. Optionally pass 'true'
        # if you want an actual Date object range rather than just a year range.
        #
        # See also "appctrl_search_range_sql" and elsewhere.
        #
        # Unavoidably duplicates code from the 'Rangeable' model base class -
        # see 'models/rangeable.rb'.
        #
        def self.used_range( accurate = false )

          first = self.unscoped.order( "#{ USED_RANGE_COLUMN } ASC"  ).first
          last  = self.unscoped.order( "#{ USED_RANGE_COLUMN } DESC" ).first

          if accurate
            ( first.created_at.to_date )..( last.created_at.to_date )
          else
            ( first.created_at.year )..( last.created_at.year )
          end
        end

      end
    end
  end
end
