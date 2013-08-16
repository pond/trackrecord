########################################################################
# File::    general_config.rb
# (C)::     Hipposoft 2008
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

# The maximum number of columns you want to allow in a report, to avoid
# excessive report size generation. This is a base figure for a normal
# task report, or task-with-user-summary report. If per-user details are
# requested, the limit is automatically halved to account for the much
# greater view generation and browser rendering load (there will be two
# full task tables rather than one).
#
# Note that for consistency with the view, generators for other data
# types will not be able to export data outside the column limit either.
# It simply isn't built inside the report; the limit is used to clamp
# the report's start date, where necessary (e.g. REPORT_MAX_COLUMNS
# days, weeks or months before the requested end date).

REPORT_MAX_COLUMNS = 400

# At the time of writing the chart controller isn't used - it was created
# for an earlier version of the report generator. It may be used again in
# future though. In that case, you should find yourself a TrueType font,
# put it in the Rails application root (i.e. next to README and LICENSE)
# and specify its leafname below.

GRAPH_FONT = "PetitaBold.ttf"
