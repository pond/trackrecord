########################################################################
# File::    email_notifier.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Send out e-mail messages when important things happen.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class EmailNotifier < ActionMailer::Base

  # Send a message to the administrator when a new user signs up. Pass the new
  # User object.
  #
  def signup_notification( user )
    recipients EMAIL_ADMIN
    from       EMAIL_ADMIN
    subject    "#{ EMAIL_PREFIX }A new user has signed up"
    body       :user        => user,
               :account_url => url_for( {
                 :protocol   => 'https',
                 :host       => EMAIL_HOST,
                 :controller => 'users',
                 :action     => 'edit',
                 :id         => user.id
               } )
  end

  # Send a message to a user when their account settings are changed. Pass the
  # User object representing the updated account.
  #
  def admin_update_notification( user )
    recipients "#{ user.name } <#{ user.email }>"
    from       EMAIL_ADMIN
    subject    "#{ EMAIL_PREFIX }Your account has been configured"
    body       :user => user
  end

end
