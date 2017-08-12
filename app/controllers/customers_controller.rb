########################################################################
# File::    customers_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage Customer objects. See models/customer.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

class CustomersController < ApplicationController

  # In place editing and security

  in_place_edit_for( :customer, :title )
  in_place_edit_for( :customer, :code  )

  before_action( :can_be_modified?, :only => [ :edit, :update, :set_customer_title, :set_customer_code ] )

  uses_prototype( :only => :index )

  # List customers.
  #
  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text  => 'Customer title', :value_method => :title,      :value_in_place => true                },
      { :header_text  => 'Customer code',  :value_method => :code,       :value_in_place => true                },
      { :header_text  => 'Created at',     :value_method => :created_at, :value_helper   => :apphelp_created_at },
    ]

    # Get the basic options hash from ApplicationController, then work out
    # the conditions on objects being fetched, including handling the search
    # form data.

    options        = appctrl_index_assist( Customer )
    active_vars    = { :active => true  }
    inactive_vars  = { :active => false }
    conditions_sql = "( customers.active = :active )\n"

    # The user may only be able to see projects associated with tasks matching
    # a specific list of IDs.

    restrictions_sql = ''

    if ( @current_user.restricted? )
      if ( @current_user.task_ids.empty? )
        restrictions_sql << 'WHERE ( customers.id = -1 )' # Never matches - forces no results
        conditions_sql    = 'AND ' << conditions_sql
      else
        restrictions_sql << "INNER JOIN projects ON ( projects.customer_id = customers.id )\n" <<
                            "INNER JOIN tasks    ON ( tasks.project_id = projects.id AND tasks.id IN (#{ @current_user.task_ids.join( ',' ) } ) )\n"
        conditions_sql    = 'WHERE ' << conditions_sql
      end
    else
      conditions_sql = 'WHERE ' << conditions_sql
    end

    # If asked to search for something, build extra conditions to do so.

    range_sql, range_start, range_end = appctrl_search_range_sql( Customer )

    unless ( range_sql.nil? )
      search = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string
      conditions_sql << "AND #{ range_sql } ( customers.title ILIKE :search OR customers.code ILIKE :search )\n"

      vars = { :search => search, :range_start => range_start, :range_end => range_end }
      active_vars.merge!( vars )
      inactive_vars.merge!( vars )
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'ApplicationController.appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }, title ASC, code ASC"
    options.delete( :order )

    # Compile the main SQL statement. Select all columns of the project, fetching
    # customers where the project's customer ID matches those customer IDs, with
    # only projects containing tasks in the user's permitted task list (if any)
    # are included, returned in the required order.

    finder_sql  = "SELECT DISTINCT customers.* FROM customers\n" <<
                  "#{ restrictions_sql }\n" <<
                  "#{ conditions_sql   }\n" <<
                  "#{ order_sql        }"

    # Now paginate using this SQL. The only difference between the active and
    # inactive cases is the value of the variables passed to Active Record for
    # substitution into the final SQL query going to the database.

    @active_customers   = Customer.paginate_by_sql( [ finder_sql, active_vars   ], options )
    @inactive_customers = Customer.paginate_by_sql( [ finder_sql, inactive_vars ], options )
  end

  # The Application Controller provides generic implementations and
  # security sufficient for the other actions in this model. See its
  # comments for details.

  # Show the Customer (via ApplicationController.appctrl_show).
  #
  def show
    appctrl_show( 'Customer' )
  end

  # Show a 'Create Customer' view (via ApplicationController.appctrl_new).
  #
  def new
    appctrl_new( 'Customer' )
  end

  # Create a Customer (via ApplicationController.appctrl_create).
  #
  def create
    appctrl_create( 'Customer', customer_params() )
  end

  # Update the customer details. We may need to update associated projects
  # and tasks too, so the update is wrapped in a transaction to allow the
  # database to roll back if anything goes wrong.
  #
  # @record is set by the "can_be_modified?" before_filter method.
  #
  def update
    begin
      Customer.transaction do

        update_tasks    = ! params[ :update_tasks    ].nil?
        update_projects = ! params[ :update_projects ].nil?

        @record.update_with_side_effects!(
          customer_params(),
          update_projects,
          update_tasks
        )

        flash[ 'notice' ] = 'Customer details updated'
        redirect_to( customers_path() )
      end

    rescue ActiveRecord::StaleObjectError
      flash[ 'error' ] = 'The customer details were modified by someone else while you were making changes. Please examine the updated information before editing again.'
      redirect_to( customer_path( @record ) )

    rescue => error
      flash[ 'error' ] = "Could not update customer details: #{ error }"
      render( :action => 'edit' )

    end
  end

  # Customers should not normally be destroyed. Only administrators
  # can do this. Works via ApplicationController.appctrl_delete.
  #
  def delete
    appctrl_delete( 'Customer' )
  end

  # Show an 'Are you sure?' prompt.
  #
  def destroy
    return appctrl_not_permitted() unless ( @current_user.admin? )

    begin
      Customer.transaction do
        destroy_tasks    = ! params[ :destroy_tasks    ].nil?
        destroy_projects = ! params[ :destroy_projects ].nil?

        record = Customer.find_by_id( params[ :id ] )
        record.destroy_with_side_effects( destroy_projects, destroy_tasks )

        if ( destroy_projects )
          if ( destroy_tasks )
            message = 'Customer, customer\'s projects and associated tasks deleted'
          else
            message = 'Customer and customer\'s projects deleted; tasks left alone'
          end
        else
          message = 'Customer deleted; projects and tasks left alone'
        end

        flash[ 'notice' ] = message
        redirect_to( customers_path() )
      end

    rescue => error
      flash[ 'error' ] = "Could not destroy customer: #{ error }"
      redirect_to( home_path() )

    end
  end

private

  # Rails 4+ Strong Parameters, replacing in-model "attr_accessible".
  #
  def customer_params
    params.require( :customer ).permit(
      :active,
      :title,
      :code,
      :description,
      :projects_attributes => [
        :customer_id,
        :active,
        :title,
        :code,
        :description
      ]
    )
  end

  # before_action method - can the item in the params hash be modified by
  # the current user?
  #
  def can_be_modified?
    @record = Customer.find_by_id( params[ :id ] )
    return appctrl_not_permitted() unless @record.can_be_modified_by?( @current_user )
  end
end
