########################################################################
# File::    help_controller.rb
# (C)::     Hipposoft 2010
#
# Purpose:: Display help pages.
# ----------------------------------------------------------------------
#           15-Jan-2010 (ADH): Created by consolidating an increasing
#                              number of duplicated help controllers.
#           18-Oct-2011 (ADH): Imported into TrackRecord.
########################################################################

class HelpController < ApplicationController

  # Hide the main heading; it is output by the view rather than letting the
  # layout do it so that both heading and body text can be wrapped in a single
  # DIV for CSS styling of the whole text block, if required.
  #
  def skip_main_heading?
    action_name == 'show'
  end

  def show
    # The ":id" value ends up being used as the name of a Partial to be
    # rendered by the 'help' view. To stop hackers putting dots, slashes
    # etc. into a URL in an attempt to get the renderer to load a different
    # Partial, only let "a-z" and underscores through.

    @partial = params[ :id ].gsub( /[^a-z_]/, '' )
  end
end
