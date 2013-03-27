########################################################################
# File::    saved_report_auto_titles_controller.rb
# (C)::     Hipposoft 2011
#
# Purpose:: Respond to AJAX requests for report titles.
# ----------------------------------------------------------------------
#           18-Oct-2011 (ADH): Created.
########################################################################

class SavedReportAutoTitlesController < ApplicationController
  def show
    render :text => "#{ Time.now }"
  end
end
