########################################################################
# File::    general_config.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: General configuration data.
# ----------------------------------------------------------------------
#           14-Oct-2008 (ADH): Created.
#           15-Oct-2009 (ADH): Removed PATH_PREFIX mechanism.
########################################################################

# The name of the organisation for which TrackRecord has been installed.
# If this is not applicable in your case, leave this set to "TrackRecord"
# so that sentences incorporating the name make sense.

ORGANISATION_NAME = 'TrackRecord'

# At the time of writing the chart controller isn't used - it was created
# for an earlier version of the report generator. It may be used again in
# future though. In that case, you should find yourself a TrueType font,
# put it in the Rails application root (i.e. next to README and LICENSE)
# and specify its leafname below.

GRAPH_FONT = "PetitaBold.ttf"
