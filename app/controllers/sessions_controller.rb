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

  skip_before_action( :appctrl_confirm_user, :only => [ :new, :create ] )

  before_action :appctrl_do_not_cache, :only => [ :new, :create ]

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
    @signin = SignIn.new

    # "browser..." comes from the 'browser' gem (see Gemfile).

    if ( browser.ie6? || browser.ie7? || browser.ie8? || browser.ie9? )
      view_context.apphelp_flash_now( :warning, :msie )
    end
  end

  # Called when the sign in form is submitted or when the OpenID plug-
  # in has completed a sign-in attempt, successfully or otherwise.

  def create

    @signin = SignIn.new( params[ :sign_in ] )

    # The OpenID subsystem ends up back at this method with a parameter
    # of "openid_url" set up, so we have to look at that too. It also
    # annoyingly *requires* this to be *set* when we're calling out.
    # There being no coherent documentation, a bodge is forced.

    @signin.identity_url  ||= params[ :openid_url ]
    params[ :openid_url ] ||= @signin.identity_url

    # Identity URL is *not* nil, but *is* empty? Form was submitted
    # with an empty string. Fall through to the password-based code.
    #
    # URL is *not* nil and is *not* empty? Form was submitted with a
    # identity URL; call OpenID authentication routine.
    #
    # URL *is* nil? We're being called from the Open ID plug-in with
    # the result of a sign-in attempt. Again, call the authentication
    # routine but don't try and read the JavaScript detection field.

    if ( not @signin.identity_url.nil? and @signin.identity_url.empty? )
      if @signin.valid?
        session[ :javascript ] = params[ :javascript ]
        process_password_sign_in_with( @signin )
      else
        render :new
      end

    else
      unless ( @signin.identity_url.nil? )
        session[ :javascript ] = params[ :javascript ]
        @signin.identity_url = User.rationalise_id( @signin.identity_url )
      end

      open_id_authentication( @signin.identity_url )
    end

  rescue => error
    failed_login(
      @signin,
      :external_message,
      :message => error.message
    )

  end

  # Sign out - may be called by a normal user or if a user decides to
  # cancel during the sign-up process.

  def destroy
    reset_session()
    view_context.apphelp_flash( :notice, :signed_out )

    redirect_to( signin_path() )
  end

protected

  def open_id_authentication( identity_url_for_test_mode )

    if ( Rails.env == "test" )

      # In test mode, bypass OpenID authentication redirections
      # since we're not interested in testing third party sites.
      # Assume sign-in was successful. Manual testing is needed
      # for "real" working/failed OpenID login.

      process_openid_sign_in_for(
        User.rationalise_id( identity_url_for_test_mode )
      )

    else

      authenticate_with_open_id do | result, identity_url |
        identity_url = User.rationalise_id( identity_url )

        if result.successful?
          process_openid_sign_in_for( identity_url )
        else
          failed_login(
            SignIn.new( params[ :sign_in ] ),
            :external_message,
            :message => result.message
          )
        end
      end

    end
  end

private

  def process_password_sign_in_with( signin_data )
    if ( signin_data.email.blank? || signin_data.password.blank? )
      failed_login( signin_data, :need_full_info )

    elsif ( User.count.zero? )
      user           = User.new
      user.email     = signin_data.email
      user.password  = signin_data.password
      user.user_type = User::USER_TYPE_ADMIN
      user.save!( :validate => false )

      # Do this only after the above "save!" has not thrown an exception.

      @current_user = user

      new_login()

    else
      user = User.find_by_email( signin_data.email )

      if ( user.nil? || user.authenticate( signin_data.password ) == false )
        failed_login( signin_data, :incorrect_info )
      else
        @current_user = user
        successful_login()
      end
    end
  end

  def process_openid_sign_in_for( identity_url )

    # The OpenID sign in went OK. If we can find an active user
    # with that ID, sign in is complete. If there's an inactive
    # user, complain. Otherwise, create a new user account - if
    # this is the first user, any OpenID will do; else it must
    # be in the permitted list.

    @current_user = User.active.find_by_identity_url( identity_url )

    if ( @current_user )
      successful_login()

    elsif ( User.inactive.find_by_identity_url( identity_url ) )
      failed_login(
        nil,
        :account_deactivated,
        :id => identity_url
      )

    elsif ( User.count.zero? )

      # Handle very first login auto-creation of the admin account.
      # Do this here because redirecting to the User controller
      # would require an exposed URL that could be used to try and
      # create users without OpenID authentication.

      user              = User.new
      user.identity_url = identity_url
      user.user_type    = User::USER_TYPE_ADMIN
      user.save!( :validate => false )

      # Do this only after the above "save!" has not thrown an exception.
      #
      @current_user = user

      new_login()

    else

      # The identity URL does not match any existing user and the
      # administrator account already exists.

      failed_login(
        nil,
        :id_not_recognised,
        :id => identity_url
      )

    end
  end

  def successful_login
    view_context.apphelp_flash( :notice, :signed_in )
    session[ :user_id ] = @current_user.id
    redirect_to( home_path() )
  end

  def new_login
    view_context.apphelp_flash( :notice, :signed_up )
    session[ :user_id ] = @current_user.id
    redirect_to( edit_user_path( @current_user ) )
  end

  def failed_login( sign_in_obj, message, substitutions = {} )
    view_context.apphelp_flash_now( :error, message, nil, substitutions )
    @signin = sign_in_obj || SignIn.new
    render :action => :new
  end
end
