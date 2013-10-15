########################################################################
# File::    sessions_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage OpenID logins. Originally created from examples in
#           the open_id_authentication plugin.
# ----------------------------------------------------------------------
#           06-Jan-2008 (ADH): Created.
########################################################################

class SessionsController < ApplicationController

  skip_before_filter( :appctrl_confirm_user,     :only => [ :new, :create           ] )
  skip_before_filter( :appctrl_ensure_user_name, :only => [ :new, :create, :destroy ] )

  # With the Rails CSRF fix/bodge (sigh), unverified requests - such as that
  # issued by the OpenID provider - cause the session to be reset. Since data
  # about JavaScript support in the sign-in form is stored there, this would
  # be lost and the system would always behave as if JS support were absent.
  #
  # The workaround is to replace the default "handle_unverified_request()"
  # implementation to deal very specifically with just this one case. Having
  # the session reset on login to contain just the JS token and, thereafter,
  # any extra data resulting from the successful (or not) login attempt keeps
  # everything clean and means that any real attempted attacks would fail.
  #
  def handle_unverified_request
    js = session[ :javascript ]
    reset_session()
    session[ :javascript ] = js
  end

  def new
    if ( User.count.zero? )
      flash[ :notice ] = 'Please sign by providing the OpenID which is to be ' <<
                         'assigned to a new administrator account.'
    end
  end

  # Called when the sign in form is submitted or when the OpenID plug-
  # in has completed a sign-in attempt, successfully or otherwise.

  def create
    identity_url = params[ :openid_url ]

    # Identity URL is *not* nil, but *is* empty? Form was submitted
    # with an empty string. URL is *not* nil and is *not* empty? Form
    # was submitted with a URL; call authentication routine. URL *is*
    # nil? We're being called from the Open ID plug-in with the result
    # of a sign-in attempt. Again, call the authentication routine but
    # don't try and read the JavaScript detection field.

    if ( not identity_url.nil? and identity_url.empty? )
      failed_login( 'You must provide an ID.')
    else
      unless ( identity_url.nil? )
        identity_url = User.rationalise_id( identity_url )
        session[ :javascript ] = params[ :javascript ]
      end

      open_id_authentication()
    end

  rescue => error
    failed_login( "An unexpected error was encountered: #{ error.message }" )
  end

  # Sign out - may be called by a normal user or if a user decides to
  # cancel during the sign-up process.

  def destroy
    user   = @current_user
    normal = ( @current_user and ( not @current_user.name.nil? ) and ( not @current_user.name.empty? ) )
    reset_session()

    if ( normal )
      flash[ :notice ] = 'You have signed out.'
    else
      user.destroy() if ( user )
      flash[ :error ] = 'Sign in process aborted.'
    end

    redirect_to( signin_path() )
  end

protected

  def open_id_authentication()

    authenticate_with_open_id do | result, identity_url |
      identity_url = User.rationalise_id( identity_url )

      if result.successful?

        # The OpenID sign in went OK. If we can find an active user
        # with that ID, sign in is complete. If there's an inactive
        # user, complain. Otherwise, create a new user account - if
        # this is the first user, any OpenID will do; else it must
        # be in the permitted list.

        if ( @current_user = User.active.find_by_identity_url( identity_url ) )
          successful_login()

        elsif ( User.inactive.find_by_identity_url( identity_url ) )
          failed_login( "The account for OpenID '#{ identity_url }' has been deactivated. Please contact your system administrator for assistance." )

        else
          # Handle very first login auto-creation of the admin account

          if ( User.count.zero? )

            # Do this here because redirecting to the User controller
            # would require an exposed URL that could be used to try
            # and create users without OpenID authentication.

            @current_user              = User.new
            @current_user.identity_url = identity_url
            @current_user.user_type    = User::USER_TYPE_ADMIN
            @current_user.save!

            new_login()

          else

            # The identity URL does not match any existing user and the
            # administrator account already exists.

            failed_login( "Sorry, OpenID '#{ identity_url }' is not permitted to use this service. Please contact your system administrator for assistance.")

          end
        end

      else
        # The OpenID login attempt failed.
        failed_login( result.message )

      end
    end
  end

private

  def successful_login
    flash[ :notice ] = 'Signed in successfully.'
    session[ :user_id ] = @current_user.id
    redirect_to( home_path() )
  end

  def new_login
    flash[ :notice ] = 'Signed in successfully. Please now fill in your timesheet system details.'
    session[ :user_id ] = @current_user.id
    redirect_to( edit_user_path( @current_user ) )
  end

  def failed_login( message )
    flash[ :error ] = message
    redirect_to( signin_path() )
  end
end
