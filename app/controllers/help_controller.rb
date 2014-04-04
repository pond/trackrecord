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

  # Security exemption to allow viewing help pages even when signed out.
  # The 'show' action implementation restricts this further.
  #
  skip_before_filter :appctrl_confirm_user, :only => :show

  # Hide the main heading; it is output by the view rather than letting the
  # layout do it so that both heading and body text can be wrapped in a single
  # DIV for CSS styling of the whole text block, if required.
  #
  def skip_main_heading?
    true
  end

  def show

    # I can't imagine how being able to view arbitrary help pages without being
    # signed in could be harmful, but to be absolutely sure, only allow the one
    # help page that's required in this case - the sign-in page information
    #
    appctrl_confirm_user && return unless params[ :id ] == "sign_in"

    # The ":id" value ends up being used as the name of a Partial to be
    # rendered by the 'help' view. To stop hackers putting dots, slashes
    # etc. into a URL in an attempt to get the renderer to load a different
    # Partial, only let "a-z" and underscores through.

    @partial = params[ :id ].gsub( /[^a-z_]/, '' )
  end
end
