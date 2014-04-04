########################################################################
# File::    email_notifier.rb
# (C)::     Hipposoft 2007
#
# Purpose:: Send out e-mail messages when important things happen.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class EmailNotifier < ActionMailer::Base

  # Send a message to a user when their account is created by an administrator.
  # Pass the new User instance and the ActionDispatch::Request instance for the
  # current controller action, so that URLs can be generated with a known host
  # and port.
  #
  def signup_notification( user, request )

    EmailNotifier.default_url_options[ :host ] = request.host_with_port

    @user        = user
    @site_name   = I18n.t( :'uk.org.pond.trackrecord.site_name' )
    @account_url = url_for(
      {
        :protocol   => 'https',
        :host       => EMAIL_HOST,
        :controller => 'users',
        :action     => 'edit',
        :id         => user.id
      }
    )

    mail(
      :to      => "#{ user.name } <#{ user.email }>",
      :from    => EMAIL_ADMIN,
      :subject => "[#{ @site_name }] Your account has been created"
    )
  end

  # Send a message to a user when their account settings are changed. Pass the
  # Pass the updated User instance and the ActionDispatch::Request instance for
  # the current controller action, so that URLs can be generated with a known
  # host and port.
  #
  def admin_update_notification( user, request )

    EmailNotifier.default_url_options[ :host ] = request.host_with_port

    @user      = user
    @site_name = I18n.t( :'uk.org.pond.trackrecord.site_name' )

    mail(
      :to      => "#{ user.name } <#{ user.email }>",
      :from    => EMAIL_ADMIN,
      :subject => "[#{ @site_name }] Your account settings have been changed"
    )
  end

end
