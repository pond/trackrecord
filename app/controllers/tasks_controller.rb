########################################################################
# File::    tasks_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage Task objects. See models/task.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

class TasksController < ApplicationController

  # In place editing and security

  safe_in_place_edit_for( :task, :title    )
  safe_in_place_edit_for( :task, :code     )
  safe_in_place_edit_for( :task, :duration )
  safe_in_place_edit_for( :task, :billable )

  before_filter(
    :can_be_modified?,
    :only =>
    [
      :edit,
      :update,
      :set_task_title,
      :set_task_code,
      :set_task_duration,
      :set_task_billable
    ]
  )

  uses_prototype( :only => :index )

  # List tasks.
  #
  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text  => 'Customer',   :sort_by      => 'customers.title', :value_helper   => :taskhelp_customer  },
      { :header_text  => 'Project',    :sort_by      => 'projects.title',  :value_helper   => :taskhelp_project   },
      { :header_text  => 'Task title', :value_method => :title,            :value_in_place => true                },
      { :header_text  => 'Task code',  :value_method => :code,             :value_in_place => true                },
      { :header_text  => 'Billable?',  :value_method => :billable,         :value_in_place => true,
        :header_align => 'center',     :value_align  => 'center'                                                  },
      { :header_text  => 'Created at', :value_method => :created_at,       :value_helper   => :apphelp_created_at },
      { :header_text  => 'Duration',   :value_method => :duration,         :value_in_place => true,
        :header_align => 'center',     :value_align  => 'center'                                                  },
    ]

    # Get the basic options hash from ApplicationController, then work out
    # the conditions on objects being fetched, including handling the search
    # form data.

    options        = appctrl_index_assist( Task )
    active_vars    = { :active => true  }
    inactive_vars  = { :active => false }
    conditions_sql = "WHERE ( tasks.active = :active )\n"

    # The user may only be able to see tasks matching a specific list of IDs.

    restrictions_sql = ''

    if ( @current_user.restricted? )
      restrictions_sql = 'AND ( '
      if ( @current_user.task_ids.empty? )
        restrictions_sql << 'tasks.id = -1' # Never matches - forces no results
      else
        restrictions_sql << "tasks.project_id = projects.id AND tasks.id IN (#{ @current_user.task_ids.join( ',' ) } )"
      end
      restrictions_sql << " )\n"
    end

    # If asked to search for something, build extra conditions to do so.

    range_sql, range_start, range_end = appctrl_search_range_sql( Task )

    unless ( range_sql.nil? )
      search    = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string
      conditions_sql << "AND #{ range_sql } ( tasks.title ILIKE :search OR tasks.code ILIKE :search OR projects.title ILIKE :search OR customers.title ILIKE :search )\n"

      vars = { :search => search, :range_start => range_start, :range_end => range_end }
      active_vars.merge!( vars )
      inactive_vars.merge!( vars )
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }, title ASC, code ASC"
    options.delete( :order )

    # Compile the main SQL statement. We want to select all columns of any
    # task, fetching projects where the project ID matches the project ID used
    # by each task and customers where the customer ID matches the customer ID
    # used by each project; LEFT OUTER JOIN means that any task lacking a
    # project or any project lacking a customer will still be included; we then
    # apply any specific search conditions determined above and finally specify
    # the order for returning results.

    finder_sql  = "SELECT tasks.* FROM tasks\n" <<
                  "LEFT OUTER JOIN projects  ON ( tasks.project_id     = projects.id  )\n" <<
                  "LEFT OUTER JOIN customers ON ( projects.customer_id = customers.id )\n" <<
                  "#{ conditions_sql   }\n" <<
                  "#{ restrictions_sql }\n" <<
                  "#{ order_sql        }"

    # Now paginate using this SQL. The only difference between the active and
    # inactive cases is the value of the variables passed to Active Record for
    # substitution into the final SQL query going to the database.

    @active_tasks   = Task.paginate_by_sql( [ finder_sql, active_vars   ], options )
    @inactive_tasks = Task.paginate_by_sql( [ finder_sql, inactive_vars ], options )
  end

  # Show details of a task. Restricted users can only see tasks in their
  # permitted tasks list. Works via ApplicationController.appctrl_show.
  #
  def show
    appctrl_show( 'Task' )
  end

  # Prepare to create a new task. Restricted users can't do this. There must
  # be at least one active project available first.
  #
  def new
    if ( Project.active.count.zero? )
      flash[ :error ] = 'You must create at least one active project first.'
      redirect_to( new_project_path() )
    else
      appctrl_new( 'Task' )
    end
  end

  # Create a new task following submission of a 'create' view form. Restricted
  # users can't do this. Works via ApplicationController.appctrl_create.
  #
  def create
    appctrl_create( 'Task' )
  end

  # Update a task following submission of an 'edit' view form.
  # Restricted users can't do this.
  #
  # @record is set by the "can_be_modified?" before_filter method.
  #
  def update

    # The update call used below deals with repercussions of changes
    # to the 'active' flag and is the reason for the transaction.

    begin
      Task.transaction do
        @record.update_with_side_effects!( params[ :task ] )

        flash[ :notice ] = 'Task details updated.'
        redirect_to( tasks_path() )
      end

    rescue ActiveRecord::StaleObjectError
      flash[ :error ] = 'The task details were modified by someone else while you were making changes. Please examine the updated information before editing again.'
      redirect_to( task_path( params[ :task ] ) )

    rescue => error
      flash[ :error ] = "Could not update task details: #{ error }"
      render( :action => 'edit' )

    end
  end

  # Tasks should not normally be destroyed. Only administrators
  # can do this. Works via ApplicationController.appctrl_delete.
  #
  def delete
    appctrl_delete( 'Task' )
  end

  def destroy
    appctrl_admin_destroy( Task )
  end

private

  # before_filter action - can the item in the params hash be modified by
  # the current user?
  #
  def can_be_modified?
    @record = Task.find_by_id( params[ :id ] )
    return appctrl_not_permitted() unless @record.can_be_modified_by?( @current_user )
  end
end
