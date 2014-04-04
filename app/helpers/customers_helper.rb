########################################################################
# File::    customers_helper.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Support functions for views related to Customer objects.
#           See controllers/customers_controller.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

module CustomersHelper

  # Return list actions appropriate for the given customer

  def customerhelp_actions( customer )
    if ( @current_user.admin? or ( customer.active and @current_user.manager? ) )
      actions = [ 'edit' ]
      actions << 'delete' if ( @current_user.admin? )
    else
      actions = []
    end

    actions.push( 'show' )
    return actions
  end

end
