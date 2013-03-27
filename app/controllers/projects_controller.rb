########################################################################
# File::    projects_controller.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Manage Project objects. See models/project.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

class ProjectsController < ApplicationController

  # In place editing and security

  safe_in_place_edit_for( :project, :title )
  safe_in_place_edit_for( :project, :code  )

  before_filter( :can_be_modified?, :only => [ :edit, :update, :set_project_title, :set_project_code ] )

  uses_prototype( :only => :index )

  # List projects.
  #
  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text  => 'Customer',      :sort_by      => 'customers.title', :value_helper   => :projecthelp_customer },
      { :header_text  => 'Project title', :value_method => :title,            :value_in_place => true                  },
      { :header_text  => 'Project code',  :value_method => :code,             :value_in_place => true                  },
      { :header_text  => 'Created at',    :value_method => :created_at,       :value_helper   => :apphelp_created_at   },
    ]

    # Get the basic options hash from ApplicationController, then work out
    # the conditions on objects being fetched, including handling the search
    # form data.

    options        = appctrl_index_assist( Project )
    active_vars    = { :active => true  }
    inactive_vars  = { :active => false }
    conditions_sql = "WHERE ( projects.active = :active )\n"

    # The user may only be able to see projects associated with tasks matching
    # a specific list of IDs.

    restrictions_sql = ''

    if ( @current_user.restricted? )
      restrictions_sql = 'INNER JOIN tasks ON ( '
      if ( @current_user.task_ids.empty? )
        restrictions_sql << 'tasks.id = -1' # Never matches - forces no results
      else
        restrictions_sql << "tasks.project_id = projects.id AND tasks.id IN (#{ @current_user.task_ids.join( ',' ) } )"
      end
      restrictions_sql << " )\n"
    end

    # If asked to search for something, build extra conditions to do so.

    unless ( params[ :search ].nil? )
      if ( params[ :search ].empty? or params[ :search_cancel ] )
        params.delete( :search )
      else
        search = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string
        conditions_sql << "AND ( projects.title ILIKE :search OR projects.code ILIKE :search OR customers.title ILIKE :search )\n"
        vars = { :search => search }
        active_vars.merge!( vars )
        inactive_vars.merge!( vars )
      end
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'ApplicationController.appctrl_index_assist'.

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

    finder_sql  = "SELECT projects.* FROM projects\n" <<
                  "LEFT OUTER JOIN customers ON ( projects.customer_id = customers.id )\n" <<
                  "#{ restrictions_sql }\n" <<
                  "#{ conditions_sql   }\n" <<
                  "#{ order_sql        }"

    # Now paginate using this SQL. The only difference between the active and
    # inactive cases is the value of the variables passed to Active Record for
    # substitution into the final SQL query going to the database.

    @active_projects   = Project.paginate_by_sql( [ finder_sql, active_vars   ], options )
    @inactive_projects = Project.paginate_by_sql( [ finder_sql, inactive_vars ], options )

    # Now patch up the deficiencies of the SQL query (see comments above).

    if ( @current_user.restricted? )
      @active_projects.uniq!
      @inactive_projects.uniq!
    end
  end

  # The Application Controller provides generic implementations and
  # security sufficient for the other actions in this model. See its
  # comments for details.

  # Show the Project (via ApplicationController.appctrl_show).
  #
  def show
    appctrl_show( 'Project' )
  end

  # Show a 'Create Project' view (via ApplicationController.appctrl_new).
  #
  def new
    appctrl_new( 'Project' )
  end

  # Create a Project (via ApplicationController.appctrl_create).
  #
  def create
    appctrl_create( 'Project' )
  end

  # Update the project details. We may need to update associated tasks
  # too, so the update is wrapped in a transaction to allow the database
  # to roll back if anything goes wrong.
  #
  # @record is set by the "can_be_modified?" before_filter method.
  #
  def update
    begin
      Project.transaction do
        update_tasks = ! params[ :update_tasks ].nil?

        @record.update_with_side_effects!(
          params[ :project ],
          update_tasks
        )

        flash[ :notice ] = 'Project details updated'
        redirect_to( projects_path() )
      end

    rescue ActiveRecord::StaleObjectError
      flash[ :error ] = 'The project details were modified by someone else while you were making changes. Please examine the updated information before editing again.'
      redirect_to( project_path( @record ) )

    rescue => error
      flash[ :error ] = "Could not update project details: #{ error }"
      render( :action => 'edit' )

    end
  end

  # Projects should not normally be destroyed. Only administrators
  # can do this. Works via ApplicationController.appctrl_delete.
  #
  def delete
    appctrl_delete( 'Project' )
  end

  # Show an 'Are you sure?' prompt.
  #
  def delete_confirm
    return appctrl_not_permitted() unless ( @current_user.admin? )

    begin
      Customer.transaction do
        destroy_tasks = ! params[ :destroy_tasks ].nil?

        record = Project.find_by_id( params[ :id ] )
        record.destroy_with_side_effects( destroy_tasks )

        if ( destroy_tasks )
          message = 'Project and its tasks deleted'
        else
          message = 'Project deleted; its tasks were left alone'
        end

        flash[ :notice ] = message
        redirect_to( projects_path() )
      end

    rescue => error
      flash[ :error ] = "Could not destroy project: #{ error }"
      redirect_to( home_path() )

    end
  end

private

  # before_filter action - can the item in the params hash be modified by
  # the current user?
  #
  def can_be_modified?
    @record = Project.find_by_id( params[ :id ] )
    return appctrl_not_permitted() unless @record.can_be_modified_by?( @current_user )
  end
end
