########################################################################
# File::    help_helper.rb
# (C)::     Hipposoft 2010
#
# Purpose:: Utility methods for views providing help text.
# ----------------------------------------------------------------------
#           15-Jan-2010 (ADH): Created.
#           18-Oct-2011 (ADH): Imported into TrackRecord.
########################################################################

module HelpHelper

  # Pass the name of a help view parial, e.g. "user_geography" or
  # "attach_video". Returns HTML consisting of an image linked to the
  # associated help page in a blank target window.
  #
  def help_link( partial )
    help_url( help_path( partial ) )
  end

  # Pass a URL. Returns HTML consisting of an image linked to the given URL
  # on the assumption that this URL is for some kind of help page.
  #
  def help_url( url )

    # We link to an image tag so that we don't have to worry about inline
    # block styling and bugs in some browsers related to those; we want an
    # image, but we want an image we can change in CSS for a 'hover' state.
    # So, use a blank foreground image and set a background image in CSS.
    # See the "help" class styling in the CSS file for the styles that make
    # things work.
    #
    # Yes, this is just Yet Another Hack for the mess that is HTML + CSS.

    link_to(
      image_tag(
        'trackrecord/blank.png',
        :size  => '16x16',
        :alt   => '?',
        :align => 'top',
        :class => 'help'
      ),
      url,
      :target => '_blank',
      :class  => 'help'
    )
  end
end
