########################################################################
# File::    saved_reports_controller.rb
# (C)::     Hipposoft 2011
#
# Purpose:: Manage saved collections of parameters used to generate
#           reports.
# ----------------------------------------------------------------------
#           19-Oct-2011 (ADH): Created.
########################################################################

class SavedReportsController < SavedReportsBaseController

  # In place editing and security - note also filters present in the
  # SavedReportsBaseController superclass.

  safe_in_place_edit_for( :saved_report, :title  )
  safe_in_place_edit_for( :saved_report, :shared )

  before_filter(
    :can_be_modified?,
    :only =>
    [
      :edit,
      :update,
      :delete,
      :destroy,
      :set_saved_report_title,
      :set_saved_report_shared
    ]
  )

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
      { :header_text => 'Name',        :value_method => 'title',                 :value_in_place => true, :sort_by => 'title'             },
      { :header_text => 'Shared',      :value_method => 'shared',                :value_in_place => true, :sort_by => 'shared'            },
      { :header_text => 'Last edited', :value_helper => 'reporthelp_updated_at',                          :sort_by => 'updated_at'        },
      { :header_text => 'Start date',  :value_helper => 'reporthelp_start_date',                          :sort_by => 'range_start_cache' },
      { :header_text => 'End date',    :value_helper => 'reporthelp_end_date',                            :sort_by => 'range_end_cache'   },
      { :header_text => 'Owner',       :value_helper => 'reporthelp_owner',                               :sort_by => 'users.name'        }
    ]

    options = appctrl_index_assist( SavedReport )
    vars    = { :user_id => @current_user.id }

     user_sql = "WHERE ( users.id  = :user_id )\n"
    other_sql = "WHERE ( users.id != :user_id )\n"

    if ( @current_user.restricted? )
      other_sql << "AND ( shared = :shared_flag )\n"
      vars[ :shared_flag ] = true
    end

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

    # Implement copying; this could've been done in a new controller
    # but no matter how you look at it, "new-with-an-ID" does not map
    # cleanly to Rails REST and doing such an action in a separate
    # controller just leads to code duplication and difficulties with
    # the concept of "current controller" etc. in the view (we end up
    # wanting to render the SavedReportsController edit view anyway).

    @record = nil

    if ( params.has_key?( :saved_report_id ) )
      found_report = SavedReport.find_by_id( params[ :saved_report_id ] ) # No exception raised if record is not found

      unless ( found_report.nil? )
        @record                  = found_report.dup
        @record.active_tasks     = found_report.active_tasks
        @record.inactive_tasks   = found_report.inactive_tasks
        @record.reportable_users = found_report.reportable_users

        @record.title << " (copy)"
      end
    end

    if ( @record.nil? )
      @record      = SavedReport.new
      @record.user = @user
    end

    @user_array = @current_user.restricted? ? [ @current_user ] : User.active
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
    @user_array = @current_user.restricted? ? [ @current_user ] : User.active
  end

  # Commit changes to an existing report. Note that some security actions,
  # e.g. making sure the list of allowed reportable users is valid or the
  # list of tasks is only that the current user can see, are enforced down
  # in the report generator. If someone hacks a view, it won't help them.
  #
  def update
    appctrl_patch_params_from_js( :saved_report, :active_task_ids   )
    appctrl_patch_params_from_js( :saved_report, :inactive_task_ids )

    if ( @record.update_attributes( params[ :saved_report ] ) )
      flash[ :notice ] = "Report details updated."
      redirect_to( report_path( @record ) )
    else
      render( :action => :edit )
    end
  end

  # For showing reports, just redirect to the dedicated controller for that.
  #
  def show
    saved_report = SavedReport.find_by_id( params[ :id ] )

    if ( saved_report.is_permitted_for?( @current_user ) )
      redirect_to( report_path( saved_report ) )
    else
      appctrl_not_permitted()
    end
  end

  # Confirm deletion of a saved report.
  #
  def delete
    # All work done via before_filters.
  end

  # Actually delete a saved report.
  #
  def destroy
    appctrl_destroy( SavedReport, user_saved_reports_path( @user ) )
  end

private

  # before_filter action - can the item in the params hash be modified by
  # the current user?
  #
  def can_be_modified?
    @record = SavedReport.find_by_id( params[ :id ] )
    return appctrl_not_permitted() unless @record.can_be_modified_by?( @current_user )
  end
end
