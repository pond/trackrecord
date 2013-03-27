########################################################################
# File::    users_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage User objects. See models/user.rb for more.
# ----------------------------------------------------------------------
#           03-Jan-2008 (ADH): Created.
########################################################################

class UsersController < ApplicationController

  # In-place editing and security

  safe_in_place_edit_for( :user, :name )
  safe_in_place_edit_for( :user, :code )

  skip_before_filter( :appctrl_confirm_user,     :only => [ :home ] )
  skip_before_filter( :appctrl_ensure_user_name, :only => [ :edit, :update, :cancel ] )

  uses_prototype( :only => :index )

  # YUI tree component for task selection

  dynamic_actions = { :only => [ :new, :create, :edit, :update ] }

  uses_leightbox( dynamic_actions )
  uses_yui_tree(
    { :xhr_url_method => :trees_path },
    dynamic_actions
  )

  # Home page - only show if logged in.
  #
  def home
    redirect_to signin_path() and return if ( @current_user.nil? )
  end

  # List users - not allowed for restricted users
  #
  def index
    return appctrl_not_permitted() if ( @current_user.restricted? )

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text => 'Name',           :value_method   => 'name',         :value_in_place => true                  },
      { :header_text => 'Code',           :value_method   => 'code',         :value_in_place => true                  },
      { :header_text => 'Account type',   :value_method   => 'user_type'                                              },
      { :header_text => 'E-mail address', :value_method   => 'email',        :value_helper => 'userhelp_email'        },
      { :header_text => 'Identity URL',   :value_method   => 'identity_url', :value_helper => 'userhelp_identity_url' },
    ]

    # Get the basic options hash from ApplicationController, then work out
    # the conditions on objects being fetched, including handling the search
    # form data.

    options        = appctrl_index_assist( User )
    active_vars    = { :active => true  }
    inactive_vars  = { :active => false }
    conditions_sql = "WHERE ( active = :active )\n"

    # If asked to search for something, build extra conditions to do so.

    range_sql, range_start, range_end = appctrl_search_range_sql( User )

    unless ( range_sql.nil? )
      search = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string
      conditions_sql << "AND #{ range_sql } ( name ILIKE :search OR email ILIKE :search OR identity_url ILIKE :search )\n"

      vars = { :search => search, :range_start => range_start, :range_end => range_end }
      active_vars.merge!( vars )
      inactive_vars.merge!( vars )
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }, name ASC, code ASC"
    options.delete( :order )

    # Compile the main SQL statement.

    finder_sql  = "SELECT * FROM users\n" <<
                  "#{ conditions_sql }\n" <<
                  "#{ order_sql      }"

    # Now paginate using this SQL. The only difference between the active and
    # inactive cases is the value of the variables passed to Active Record for
    # substitution into the final SQL query going to the database.

    @active_users   = User.paginate_by_sql( [ finder_sql, active_vars   ], options )
    @inactive_users = User.paginate_by_sql( [ finder_sql, inactive_vars ], options )
  end

  # Show user details.
  #
  def show
    @user = User.find( params[ :id ] )
    return appctrl_not_permitted() unless ( @user and ( @current_user.privileged? or @user == @current_user ) )
  end

  # Never allow direct creation attempts. User creation is done via
  # session management. The only exception is for administrators, who
  # may (carefully!) choose to create user accounts up-front after
  # adding an ID to the permitted list.
  #
  def new
    return appctrl_not_permitted() unless @current_user.admin?
    @record = @user = User.new
  end

  # Create a new User account.
  #
  def create
    return appctrl_not_permitted() unless @current_user.admin?

    @record = @user = User.new
    @control_panel = @user.control_panel = ControlPanel.new

    update_and_save_user( 'New account created', 'new' )
  end

  # Prepare for the 'edit' view, allowing a user to update their
  # account details. Restricted users can only edit their own account.
  #
  def edit
    id = params[ :id ]

    if ( @current_user.restricted? and @current_user.id != id.to_i )
      return appctrl_not_permitted()
    end

    @user          = User.find( id )
    @control_panel = @user.control_panel
  end

  # Update a User following submission of an 'edit' view form.
  # Restricted users can only edit their own account.
  #
  def update
    id = params[ :id ]

    if ( @current_user.restricted? and @current_user.id != id.to_i )
      return appctrl_not_permitted()
    end

    @user = User.find( id )

    if ( @current_user.admin? and params[ :notify_user ] )
      EmailNotifier.admin_update_notification( @user ).deliver()
    end

    # New user just set up a previously uninitialised account (no
    # e-mail yet stored - update_and_save_user will take that from
    # the params hash) or a normal account edit?

    if ( @user.nil? or @user.name.empty? )
      if ( User.count == 1 )
        message = 'New administrator account created. You can now set up whatever ' <<
                  'initial customers, projects and tasks you need.'
      else
        message = 'New account created. Before you can use the service fully, the '   <<
                  'administrator will have to configure some account settings. You '  <<
                  'will be notified by e-mail when this process is complete. Please ' <<
                  "direct queries to the administrator at '#{ EMAIL_ADMIN }'."
      end

      update_and_save_user(
        message,
        'edit',
        true
      )
    else
      update_and_save_user( 'User details updated.', 'edit' )
    end
  end

  # Cancel a sign in account edit request.
  #
  def cancel
    id    = params[ :id ]
    @user = User.find( id )

    # We must have found a user in the database matching the ID.
    # The ID must be provided. There must be a currently logged in
    # user and their ID must match that of the cancellation request.
    # The user must not have a name yet - if they do, it implies a
    # created, active account.

    if ( @user.nil? or id.nil? or @current_user.nil? or ( id.to_i() != @current_user.id ) or @user.name )
      flash[ :error ] = "Cancellation request not understood."
    else
      @user.destroy()
      flash[ :error ] = 'Sign in cancelled.'
    end

    redirect_to( signout_path() )
  end

  # Users should not normally be destroyed. Only administrators
  # can do this.
  #
  def delete
    appctrl_delete( 'User' )
  end

  # Show an "Are you sure?" prompt.
  #
  def delete_confirm
    return appctrl_not_permitted() unless ( @current_user.admin? )

    # Nobody can delete admin accounts. You must assign the admin
    # privilege to someone else, then, since you can't revoke your
    # own admin privileges either, have the new admin change your
    # account type and delete the user record. This is a good way
    # of ensuring that there is always at least one admin.

    @record = User.find( params[ :id ] )
    return appctrl_not_permitted() if ( @record.admin? )

    @record.destroy()

    flash[ :notice ] = 'User and all associated data deleted'
    redirect_to( users_path() )
  end

private

  # Update @user based on the params hash. Saves the result. Pass a
  # message to show on success or an action to render on failure. Make
  # sure appropriate instance variables exist for the associated on-
  # failure view to be displayed. The optional third parameter should
  # be set to 'true' if an update notification is to be sent to the user
  # if the update succeeds. By default, no message is sent.
  #
  # This gets complex because both a User and the user's ControlPanel
  # object get updated.
  #
  def update_and_save_user( success_message, failure_action, send_email = false)

    User.transaction do

      appctrl_patch_params_from_js( :user          )
      appctrl_patch_params_from_js( :control_panel )

      # Rails does not quite understand the way we update the associated
      # control panel yet want to save everything in a way which rolls back
      # both objects should either validation failed. To achieve this, the
      # user needs to be updated and saved in a transaction - which will
      # save the unmodified associated control panel, but not roll that
      # control panel back should the user fail in some way (doh) - then,
      # within the user transaction, update and explicitly save just the
      # control panel. Should that go wrong, the transaction for the control
      # panel will roll back, followed by the transaction for the user.

      @user.attributes = params[ :user ]

      # Only assign task IDs if the user is privileged (managers, admins).

      if ( @current_user.privileged? )
        if ( params[ :user ][ :task_ids ].nil? )
          @user.task_ids = []
        else
          @user.task_ids = params[ :user ][ :task_ids ]
        end
      end

      # If the current user is a manager or administrator, allow
      # changes to the account type, with some catches; managers
      # can't assign admin privileges and admins can't revoke
      # admin privileges on their own account. Attempts to change
      # such things implies hacking, since the view doesn't allow
      # it - simply silently ignore it.

      if ( params[ :user ][ :user_type ] )
        if ( @current_user.admin? )
          if ( @user.id != @current_user.id )
            @user.user_type = params[ :user ][ :user_type ]
          end
        elsif ( @current_user.manager? )
          user_type = params[ :user ][ :user_type ]
          @user.user_type = user_type if ( user_type != User::USER_TYPE_ADMIN )
        end
      end

      # Validation will fail if the user's task list includes any
      # inactive tasks. Managers and administrators can fix this,
      # so leave them alone. If a restricted user is updating their
      # account, though, they can't fix it; so do it for them.
      #
      # This needs to be done in the Controller rather than the
      # Model because our actions depend upon properties of the
      # currently logged in user, not the user being modified.
      #
      # (NB, changing a task to inactive ought to lead to all users
      # being updated, but catch things here just in case).

      @user.remove_inactive_tasks() if ( @current_user.restricted? )
      @user.save!

      # Now update the control panel within the user transaction.

      ControlPanel.transaction do
        @user.control_panel.attributes = params[ :control_panel ]

        # Annoying glitch - if the user empties the task list for the
        # control panel, the above code does NOT empty the corresponding
        # model property. Instead the missing hash contents are taken to
        # mean 'no change'.

        @user.control_panel.tasks = [] if ( params[ :control_panel ].nil? or params[ :control_panel ][ :task_ids ].nil? )

        # As with the user, remove inactive tasks, then save.

        @user.control_panel.remove_inactive_tasks() if ( @current_user.restricted? )
        @user.control_panel.save!

        begin
          EmailNotifier.signup_notification( @user ).deliver() if ( send_email )
          flash[ :notice ] = success_message
        rescue => error
          flash[ :notice ] = success_message + " Please note, though, that the notification e-mail message could not be sent: #{ error.message }"
        end

        redirect_to( home_path() )
      end
    end

  rescue ActiveRecord::StaleObjectError
    @user.control_panel.valid? # Check for control panel errors even if the user save failed
    flash[ :error ] = 'The user details were modified by someone else while you were making changes. Please examine the updated information before editing again.'
    redirect_to( user_path( @user ) )

  rescue => error
    flash[ :error ] = error.message
    @user.control_panel.valid? # Check for control panel errors even if the user save failed
    render( :action => failure_action )

  end
end
