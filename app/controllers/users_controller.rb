########################################################################
# File::    users_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage User objects. See models/user.rb for more.
# ----------------------------------------------------------------------
#           03-Jan-2008 (ADH): Created.
########################################################################

class UsersController < ApplicationController

  skip_before_filter( :appctrl_ensure_user_is_valid,
                      :only => [ :new, :create, :edit, :update, :cancel ] )

  before_filter :set_simple_password_suggestion, :only => [ :new, :create, :edit, :update ]

  # SecureRandom is used for simple password suggestions for the temporary
  # initial password on new accounts.

  require 'securerandom'

  # In-place editing

  uses_prototype( :only => :index )

  in_place_edit_for( :user, :name )
  in_place_edit_for( :user, :code )

  # YUI tree component for task selection

  dynamic_actions = { :only => [ :new, :create, :edit, :update ] }

  uses_leightbox( dynamic_actions )
  uses_yui_tree(
    { :xhr_url_method => :trees_path },
    dynamic_actions
  )

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

    @user                     = User.new
    @user.must_reset_password = true
  end

  # Create a new User account.
  #
  def create
    return appctrl_not_permitted() unless @current_user.admin?

    @user                                = User.new
    @control_panel = @user.control_panel = ControlPanel.new

    update_and_save_user(
      :added,
      'new',
      params[ :notify_user ].present?
    )
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

    # Normally, user accounts are only ever created through this controller,
    # so they're subject to normal user validation rules. This means the name
    # field of a record obtained from the database cannot be empty. However,
    # for the very first user to sign up, the Sessions Controller makes a
    # sort of skeleton User object and saves it bypassing validation, then
    # redirects to the User Controller's edit action.

    message = if ( @user.name.empty? && User.count == 1)
      :initial_signup
    else
      :updated
    end

    update_and_save_user(
      message,
      'edit',
      @current_user.privileged? && params[ :notify_user ].present?
    )
  end

  # Cancel a sign in account edit request.
  #
  def cancel

    @user = User.find( params[ :id ] )

    # We must have an ID and must find a user under that ID (else an exception
    # is thrown); this must match the current user; and the record must not yet
    # be valid, implying in-progress first time account setup.

    if ( @current_user.nil? or @current_user.id != @user.id or @current_user.valid? )
      flash[ :error ] = "Cancellation request not understood."
      redirect_to( home_path() )
    else
      @user.destroy()
      reset_session()
      flash[ :error ] = 'Sign up cancelled.'
      redirect_to( signin_path() )
    end
  end

  # Users should not normally be destroyed. Only administrators
  # can do this.
  #
  def delete
    appctrl_delete( 'User' )
    @user = @record # (historical)
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

    @user = User.find( params[ :id ] )
    return appctrl_not_permitted() if ( @user.admin? )

    @user.destroy()

    flash[ :notice ] = 'User and all associated data deleted'
    redirect_to( users_path() )
  end

private

  # Update '@user' based on the params hash. Saves the result. Pass a lookup
  # token (for 'apphelp_flash') that yields the message to show on success;
  # pass also an action to render upon failure. Ensure appropriate instance
  # variables exist for the associated on-failure view to be displayed.
  #
  # The optional third parameter, defaulting to 'false', is set to 'true' if
  # an update notification is to be sent to the user if the update succeeds.
  # By default, no message is sent. The nature of the e-mail depends on
  # whether or not @user is a new record (sends an 'account created' message)
  # or updated (sends an 'account changed' message).
  #
  # Internally, this gets complex because both the user object and the user's
  # ControlPanel object get updated.
  #
  def update_and_save_user( success_token, failure_action, send_email = false)

    User.transaction do

      appctrl_patch_params_from_js( :user          )
      appctrl_patch_params_from_js( :control_panel )

      # Was this a new record? We'll use this information later for sending
      # out e-mail messages *after* successfully saving the model.

      user_is_new = @user.new_record?

      # Work out the "must reset password" flag, which is hardly ever taken
      # from "params"! *Set* the required value in "params" so that it gets
      # transferred to "@user" further down, when we update attributes from
      # the parameters hash. Consider:
      #
      # - A new account with a password must have the flag set unless this is
      #   for first-time signup (more than zero accounts exist already) to
      #   force all new users to reset (since first-time passwords get sent
      #   out in the clear over e-mail).
      #
      # - An admin editing someone else's account who has set a flag value in
      #   the form should have that value respected and used.
      #
      # - Anyone else, of any privilege, editing any account has the flag
      #   preserved *unless* they're the account owner and they are setting a
      #   new password.

      if ( user_is_new )
        # New account, set the flag if using a password for non-first users.
        params[ :user ][ :must_reset_password ] = params[ :user ][ :password ].present? && User.count.nonzero?

      elsif ( @current_user.admin? and @current_user != @user and params[ :user ].has_key?( :must_reset_password ) )
        # Leave the form-set value alone

      else
        # Editing own or non-admin (i.e. manager) editing other account;
        # preserve flag value, only clear if owner is setting a new password.

        params[ :user ][ :must_reset_password ] = @user.must_reset_password

        if ( @current_user == @user and params[ :user ][ :new_password ].present? )
          params[ :user ][ :must_reset_password ] = false
        end

      end

      # Rails does not quite understand the way we update the associated
      # control panel yet want to save everything in a way which rolls back
      # both objects should either validation failed. To achieve this, the
      # user needs to be updated and saved in a transaction - which will
      # save the unmodified associated control panel, but not roll that
      # control panel back should the user fail in some way (doh) - then,
      # within the user transaction, update and explicitly save just the
      # control panel. Should that go wrong, the transaction for the control
      # panel will roll back, followed by the transaction for the user.

      @user.attributes = sanitised_params()

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

      unless @user.save
        @user.must_reset_password = true if user_is_new # Make sure the form reflects the 'expected' initial value
        render( :action => failure_action )

      else
        # Now update the control panel within the user transaction.

        ControlPanel.transaction do
          @user.control_panel.task_ids    = params[ :control_panel ][ :task_ids    ] || []
          @user.control_panel.project_id  = params[ :control_panel ][ :project_id  ]
          @user.control_panel.customer_id = params[ :control_panel ][ :customer_id ]

          # As with the user, remove inactive tasks, then save.

          @user.control_panel.remove_inactive_tasks() if ( @current_user.restricted? )
          @user.control_panel.save!

          begin
            if ( send_email )
              if ( user_is_new )
                EmailNotifier.signup_notification( @user, request() ).deliver()
              else
                EmailNotifier.admin_update_notification( @user, request() ).deliver()
              end
            end

            view_context.apphelp_flash(
              :notice,
              success_token
            )

          rescue => error

            view_context.apphelp_flash(
              :notice,
              :success_without_email,
              self,
              {
                :success_message => t( "uk.org.pond.trackrecord.controllers.users.flash_#{ success_token }" ),
                :error_message   => error.message
              }
            )

          end

          redirect_to( home_path() )
        end
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

  # Set a simple randomised password in "@suggestion" - intended to be shown
  # in views as a suggested *temporary* password only for use in conjunction
  # with the must-reset flag.
  #
  def set_simple_password_suggestion()
    @suggestion = @current_user.admin? ? SecureRandom.hex( 5 ) : nil
  end

private

  # Rails 4+ Strong Parameters, replacing in-model "attr_accessible". The
  # User create/update code is complex so uses this in an unusual way and
  # only one particular touchpoint; in other places, "params[ :user ]" is
  # addressed (when safe) directly (for specific other key/value pairs).
  #
  def sanitised_params
    params.require( :user ).permit(
      :identity_url,
      :name,
      :email,
      :code,
      :active,
      :password_digest,
      :must_reset_password
    )
  end
end
