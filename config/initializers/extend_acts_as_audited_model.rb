########################################################################
# File::    extend_acts_as_audited_model.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Extend acts_as_audited's Audit model to include constants
#           used by TrackRecord's shared list view code.
# ----------------------------------------------------------------------
#           26-Jun-2008 (ADH): Created.
########################################################################

class Audit

  # Define default sort order for caller convenience

  DEFAULT_SORT_COLUMN    = 'created_at'
  DEFAULT_SORT_DIRECTION = 'DESC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

end
