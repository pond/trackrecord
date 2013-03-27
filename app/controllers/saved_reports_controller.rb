########################################################################
# File::    saved_reports_controller.rb
# (C)::     Hipposoft 2011
#
# Purpose:: Managed saved collections of parameters used to generate
#           reports.
# ----------------------------------------------------------------------
#           19-Oct-2011 (ADH): Created.
########################################################################

class SavedReportsController < SavedReportsBaseController

  uses_prototype( :only => :index )
  uses_leightbox()
  uses_yui_tree(
    { :xhr_url_method => :trees_path },
    { :only => [ :new, :edit ] }
  )

  # List reports.
  #
  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text => 'Name',        :value_method => 'title',                 :value_in_place => true, :sort_by => 'title'      },
      { :header_text => 'Shared',      :value_method => 'shared',                :value_in_place => true, :sort_by => 'shared'     },
      { :header_text => 'Last edited', :value_helper => 'reporthelp_updated_at',                          :sort_by => 'updated_at' },
      { :header_text => 'Start date',  :value_helper => 'reporthelp_start_date'                                                    },
      { :header_text => 'End date',    :value_helper => 'reporthelp_end_date'                                                      },
      { :header_text => 'Owner',       :value_helper => 'reporthelp_owner',                               :sort_by => 'users.name' }
    ]

    options = appctrl_index_assist( SavedReport )
    vars    = { :user_id => @current_user.id }

     user_sql = "WHERE ( users.id  = :user_id )\n"
    other_sql = "WHERE ( users.id != :user_id )\n"

    range_sql, range_start, range_end = appctrl_search_range_sql( SavedReport )

    unless ( range_sql.nil? )
      search_num = params[ :search ].to_i
      search_str = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string

      conditions_sql = "AND #{ range_sql } ( saved_reports.name ILIKE :search_str OR users.name ILIKE :search_str )"

       user_sql << conditions_sql
      other_sql << conditions_sql

      vars.merge!( { :search_str => search_str, :search_num => search_num, :range_start => range_start, :range_end => range_end } )
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }"
    options.delete( :order )

    # Compile the main SQL statement. Select all columns of the project, fetching
    # customers where the project's customer ID matches those customer IDs, with
    # only projects containing tasks in the user's permitted task list (if any)
    # are included, returned in the required order.
    #
    # Due to restrictions in the way that DISTINCT works, I just cannot figure out
    # ANY way in SQL to only return unique projects while still matching the task
    # permitted ID requirement for restricted users. So, fetch duplicates, then
    # strip them out in Ruby afterwards (ouch).

    basic_sql = "SELECT saved_reports.* FROM saved_reports\n"                <<
                "INNER JOIN users ON ( saved_reports.user_id = users.id )\n"

     user_sql = "#{ basic_sql }\n#{  user_sql }\n#{ order_sql }"
    other_sql = "#{ basic_sql }\n#{ other_sql }\n#{ order_sql }"

    # Now paginate using this SQL query.

     @user_reports = SavedReport.paginate_by_sql( [  user_sql, vars ], options );
    @other_reports = SavedReport.paginate_by_sql( [ other_sql, vars ], options );
  end

  # Prepare for the 'new report' view.
  #
  def new
    @saved_report      = SavedReport.new
    @saved_report.user = @user
    @user_array        = @current_user.restricted? ? [ @current_user ] : User.active
  end

  # Generate a report based on a 'new report' form submission.
  #
  def create
    appctrl_patch_params_from_js( :saved_report, :active_task_ids   )
    appctrl_patch_params_from_js( :saved_report, :inactive_task_ids )

    saved_report      = SavedReport.new( params[ :saved_report ] )
    saved_report.user = @user

    if ( saved_report.save )
      redirect_to( report_path( saved_report ) )
    else
      render( :action => :new )
    end
  end

  # Edit an existing report.
  #
  def edit
    @saved_report = SavedReport.find( params[ :id ] )
    @user_array   = @current_user.restricted? ? [ @current_user ] : User.active
  end

  # Commit changes to an existing report.
  #
  def update
    saved_report = SavedReport.find( params[ :id ] )

    appctrl_patch_params_from_js( :saved_report, :active_task_ids   )
    appctrl_patch_params_from_js( :saved_report, :inactive_task_ids )

    if ( saved_report.update_attributes( params[ :saved_report ] ) )
      flash[ :notice ] = "Report details updated"
      redirect_to( report_path( saved_report ) )
    else
      render( :action => :edit )
    end
  end

  # For showing reports, just redirect to the dedicated controller for that.
  #
  def show
    saved_report = SavedReport.find( params[ :id ] )
    redirect_to( report_path( saved_report ) )
  end
end
