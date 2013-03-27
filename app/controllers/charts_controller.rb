########################################################################
# File::    charts_controller.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Use the Gruff library to generate charts in PNG format for
#           inclusion in HTML reports.
# ----------------------------------------------------------------------
#           11-Mar-2008 (ADH): Created.
########################################################################

class ChartsController < ApplicationController

  # Show a graph. See charts_helper.rb for the way to generate a URL that
  # will correctly convey the required parameters. Essentially, the ID is
  # used to carry the chart type and extra query string parameters carry
  # additional required parameters. This is more of a 'create' action
  # than 'show', but since it's used for things like showing reports and
  # the charts are usually generated on-demand as part of IMG tags, it is
  # far more natural from the caller's perspective to use 'show'.

  def show

    # Extract the request parameters

    type = params[ :id ]

    raise "Chart type #{type} is unknown" if ( type != ChartsHelper::CHART_TYPE_PIE.to_s )

    leaf          = ( params[ :leaf          ] || 'chart' )
    width         = ( params[ :width         ] || '128'   ).to_i
    duration      = ( params[ :duration      ] || '1_0'   ).sub( '_', '.' ).to_f
    committed     = ( params[ :committed     ] || '0_2'   ).sub( '_', '.' ).to_f
    not_committed = ( params[ :not_committed ] || '0_5'   ).sub( '_', '.' ).to_f
    remaining     = duration - committed - not_committed

    # Stop silly widths from loading the server unnecessarily.

    width = 40  if ( width < 40  );
    width = 640 if ( width > 640 );

    g                  = Gruff::Mini::Pie.new( "#{ width }x#{ width * 0.75 }" )
    g.title            = 'Chart'
    g.font             = "#{ RAILS_ROOT }/#{ GRAPH_FONT }"
    g.hide_legend      = true
    g.hide_title       = true
    g.marker_font_size = 70

    # Is this a normal or overrun graph?

    if ( remaining >= 0 or duration == 0 )

      g.theme = {
        :colors            => %w( #cc7777 #ffaa77 #99ff99 ),
        :background_colors => %w( white   white           ),
        :marker_color      => 'black'
      }

      # Can't have a pie chart where every entry has zero size;
      # set the remaining time to 100 (as in, 100%) in that case.

      remaining = 0   if ( remaining  < 0 ) # Zero duration task
      remaining = 100 if ( remaining == 0 and committed == 0 and not_committed == 0 )

      g.data( 'Committed',     committed     )
      g.data( 'Not committed', not_committed )
      g.data( 'Remaining',     remaining     )

    else

      g.theme = {
        :colors            => %w( #ffaa77 #880000 #000000 ),
        :background_colors => %w( white   white           ),
        :marker_color      => 'black'
      }

      g.data( 'Duration', duration   )
      g.data( 'Overrun',  -remaining )
      g.data( '-', 0 )

    end

    # Start the chart at 12:00

    g.zero_degree = -90

    # Send out the result

    send_data(
      g.to_blob,
      :disposition => 'inline',
      :type        => 'image/png',
      :filename    => "#{ leaf }.png"
    )
  end
end
