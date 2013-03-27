########################################################################
# File::    charts_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Help views use the charts controller.
# ----------------------------------------------------------------------
#           11-Mar-2008 (ADH): Created.
########################################################################

module ChartsHelper

  CHART_TYPE_PIE = 0

  # Return an image URL which will resolve to a pie chart summarising
  # a task based on the given duration, committed and not committed
  # hours, using the given width (pixels).

  def charthelp_image_url( duration, committed, not_committed, width )

    # Rails routes don't like "." appearing in the middle of a URL.
    # "CGI.escape()" doesn't touch them, so change them manually to
    # underscores for maximum inoffensiveness! The controller changes
    # them back.

    duration      = duration.to_s.sub( '.', '_' )
    committed     = committed.to_s.sub( '.', '_' )
    not_committed = not_committed.to_s.sub( '.', '_' )

    return chart_url(
      CHART_TYPE_PIE,
      :width         => width,
      :duration      => duration,
      :committed     => committed,
      :not_committed => not_committed
    )
  end

  # Return an HTML <img> tag which includes a Gruff-generated pie
  # chart summarising a task based on the given duration, committed
  # and not committed hours, using the given width and height
  # (pixels). The height of the generated image tends to depend on
  # Gruff, so it's only given the width. If you wish to have the
  # image appear undistorted, generate one at the given width, check
  # its actual height then use that value from then on.

  def charthelp_image( duration, committed, not_committed, width, height )
    return image_tag(
      charthelp_image_url( duration, committed, not_committed, width ),
      {
        :size  => "#{ width }x#{ height }",
        :alt   => "Overview",
        :align => "left"
      }
    )
  end
end
