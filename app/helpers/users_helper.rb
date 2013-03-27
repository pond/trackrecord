########################################################################
# File::    users_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Support functions for views related to User objects. See
#           controllers/users_controller.rb for more.
# ----------------------------------------------------------------------
#           03-Jan-2008 (ADH): Created.
########################################################################

module UsersHelper

  # Output HTML for the given form and user which produces a selection
  # list allowing the user account type to be chosen. It is assumed that
  # the caller has permission to edit the user in this way.
  #
  # The including template should use appropriate container tags for the
  # output (e.g. a paragraph or table cell).

  def userhelp_user_type_selector( form, user )
    if ( @current_user.id == user.id and user.admin? )

      # You can't change your own account type if you are an administrator.
      # This is an easy way to prevent all administrators losing privilege,
      # leaving no administrator in the system.

      output  = "          Administrators cannot change account type. If you\n"
      output << "          want to stop being an administrator, first assign\n"
      output << "          administrative rights to another account, then\n"
      output << "          have that user change your account type for you."

    elsif ( not @current_user.admin? and user.admin? )

      # If the editing account is administrative but the user is not,
      # then the account type can't be changed (managers can only assign
      # privilege up to manager).

      output  = "          Administrator. Only another administrator can change\n"
      output << "          this user's account type.\n"

    else

      # OK, this is your account and you're not an administrator, or
      # it is someone else's account and they're not an administrator.

      if ( @current_user.admin? )
        warn    = false
        options = [
                    [ 'Normal',        'Normal'  ],
                    [ 'Manager',       'Manager' ],
                    [ 'Administrator', 'Admin'   ]
                  ]
      else
        warn    = true
        options = [
                    [ 'Normal',  'Normal'  ],
                    [ 'Manager', 'Manager' ]
                  ]
      end

      output = apphelp_select( form, :user_type, options, false )

      if ( warn and @current_user.id == user.id )
        output << "\n\n"
        output << "          <p>\n"
        output << "            Note that if you revoke your own account privileges,\n"
        output << "            you will need the help of another manager or an\n"
        output << "            administrator if you want to restore them later.\n"
        output << "          </p>"
      end
    end

    return output
  end

  # Output HTML for the given form and user which produces a selection
  # list allowing the user's 'active' flag to be changed. It is assumed
  # that the caller has permission to edit the user in this way.

  def userhelp_active_selector( form, user )
    return apphelp_select(
      form,
      :active,
      [
        [ 'Active',      true  ],
        [ 'Deactivated', false ]
      ],
      false
    )
  end

  # Output HTML for the given user's control panel editing section within a
  # wider user editing form, which lets the user choose the default project
  # associated with new tasks.
  #
  # The including template should use appropriate container tags for the
  # output (e.g. a paragraph or table cell).

  def userhelp_default_project_selector( user )
    unless( Project.active.count.zero? )
      output = apphelp_project_selector(
        'control_panel_project_id',
        'control_panel[project_id]',
        user.control_panel.nil? ? nil : user.control_panel.project_id,
        true
      )

      if( user.restricted? )
        output << "\n\n"
        output << "          <p>\n"
        output << "            This list is only relevant to users with a\n"
        output << "            privileged account type because normal users\n"
        output << "            cannot create new tasks.\n"
        output << "          </p>"
      end
    else
      output  = "          There are no active projects. Please\n"
      output << "          #{ link_to( 'create at least one', new_project_path() ) }."
    end

    return output
  end

  # Output HTML for the given control panel form (fields_for...) and user
  # which lets the user choose the default customer associated with new
  # projects.
  #
  # The including template should use appropriate container tags for the
  # output (e.g. a paragraph or table cell).

  def userhelp_default_customer_selector( cp, user )
    customers = Customer.active

    unless( customers.empty? )
      output = apphelp_collection_select( cp, :customer_id, customers, :id, :title, false )

      if( user.restricted? )
        output << "\n\n"
        output << "          <p>\n"
        output << "            This list is only relevant to users with a\n"
        output << "            privileged account type because normal users\n"
        output << "            cannot create new tasks.\n"
        output << "          </p>"
      end
    else
      output  = "          There are no active customers. Please\n"
      output << "          #{ link_to( 'create at least one', new_customer_path() ) }."
    end

    return output
  end

  # List view helper - format the given user's e-mail address as a link; do
  # so using auto_link so we don't have to worry about malformed addresses.
  # That's the main reason for doing this in a helper rather than manually,
  # within the model.

  def userhelp_email( user )
    return auto_link( h( user.email ) )
  end

  # As above, but for the user's identity URL

  def userhelp_identity_url( user )
    return auto_link( h( user.identity_url ) )
  end

  # Return list actions appropriate for the given user

  def userhelp_actions( user )
    actions = [ 'edit' ]
    actions.push( 'delete' ) unless user.admin?
    actions.push( 'show' )
    return actions
  end
end
