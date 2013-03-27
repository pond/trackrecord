########################################################################
# File::    application_controller.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Standard Rails application controller.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
#           21-Oct-2009 (ADH): Renamed from application.rb to
#                              application_controller.rb for Rails 2.3.
########################################################################

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'b5a52d118c1fccbdae5cfcecaf1da0e5'

  # Make sure that @current_user is set to the User object of whoever
  # is presently logged in, or 'nil' if nobody is logged in, whenever
  # any action runs. If there is no user, redirect to the Home page.
  # If the current user has no user name then force them back to the
  # 'edit user' page to set one.

  before_filter(
    :appctrl_set_user,
    :appctrl_confirm_user,
    :appctrl_ensure_user_name
  )

protected

  # Required by acts_as_audited; returns current user, setting the
  # @current_user variable in passing if it is presently unset.

  def current_user
    appctrl_set_user()
    return @current_user
  end

  # If a Controller determines than an action is not permitted, it
  # should call here. Redirects to Home with a permissions message.

  def appctrl_not_permitted
    render( { :text => 'Action not permitted', :status => 403 } )
  end

  #############################################################################
  # ACTION ASSISTANCE
  #############################################################################

  # Common code for a 'show' back-end. Pass a model name as a string.
  # Invokes 'is_permitted_for?' on the instance to check for
  # authority to proceed.
  #
  # If successful, sets "@record" and renders the view.

  def appctrl_show( model )
    @record = model.constantize.find( params[ :id ] )
    return appctrl_not_permitted() unless ( @record.is_permitted_for?( @current_user ) )
  end

  # Prepare to create a new object. Restricted users can't do this.
  # Pass a model name as a string.
  #
  # If successful, sets "@record" and renders the view.

  def appctrl_new( model )
    return appctrl_not_permitted() if ( @current_user.restricted? )

    @record = model.constantize.new
    @record.assign_defaults( @current_user )
  end

  # Create a new object following submission of a 'create' view form.
  # Restricted users can't do this. Pass the model name as a string.

  def appctrl_create( model )
    return appctrl_not_permitted() if ( @current_user.restricted? )

    @record = model.constantize.new( params[ model.downcase ] )

    if ( @record.save )
      flash[ :notice ] = "New #{ model.downcase } added"
      redirect_to( send( "#{ model.downcase.pluralize }_path" ) )
    else
      render( :action => 'new' )
    end
  end

  # Prepare to edit an object. Restricted users can't do this.
  # Pass a model name as a string.
  #
  # If successful, sets "@record" and renders the view.

  def appctrl_edit( model )
    return appctrl_not_permitted() if ( @current_user.restricted? )
    @record = model.constantize.find( params[ :id ] )
  end

  # Update an object following submission of an 'edit' view form.
  # Restricted users can't do this. Pass the model name as a string.

  def appctrl_update( model )
    return appctrl_not_permitted() if ( @current_user.restricted? )

    @record = model.constantize.find( params[ :id ] )

    if ( @record.update_attributes( params[ model.downcase ] ) )
      flash[ :notice ] = "#{ model } details updated"
      redirect_to( send( "#{ model.downcase.pluralize }_path" ) )
    else
      render( :action => 'edit' )
    end
  end

  # Prepare to delete an object. Only administrators can do this.
  # Pass the model name as a string.
  #
  # If successful, sets "@record" and renders the view.

  def appctrl_delete( model )
    return appctrl_not_permitted() unless ( @current_user.admin? )
    @record = model.constantize.find( params[ :id ] )
  end

  # Destroy an object following confirmation that this is desired.
  # Only administrators can do this. Pass the model name as a string.

  def appctrl_delete_confirm( model )
    return appctrl_not_permitted() unless ( @current_user.admin? )

    begin
      model.constantize.destroy( params[ :id ] )

      flash[ :notice ] = "#{ model } deleted"
      redirect_to( send( "#{ model.downcase.pluralize }_path" ) )

    rescue => error
      flash[ :error ] = "Could not destroy #{ model.downcase }: #{ error }"
      redirect_to( home_path() )

    end
  end

  # Take out some common code for index views. Deals with the pagination
  # and sorting parameters. Returns a hash suitable for passing on to
  # the paginator. Requires @columns to already be set up; see the index
  # helper methods in application_helper.rb for details, or look at the
  # index method in the User controller as an example. Note that parameter
  # "value_method" is required in the columns data even if a helper
  # method has been given, for sorting purposes.

  def appctrl_index_assist( model )
    default_direction = model::DEFAULT_SORT_DIRECTION.downcase
    default_entries   = 10
    default_page      = 1

    params[ :sort      ] = "#{ -1                }" if ( params[ :sort      ].nil? )
    params[ :page      ] = "#{ default_page      }" if ( params[ :page      ].nil? )
    params[ :entries   ] = "#{ default_entries   }" if ( params[ :entries   ].nil? )
    params[ :direction ] = "#{ default_direction }" if ( params[ :direction ].nil? )

    sort    = params[ :sort    ].to_i
    page    = params[ :page    ].to_i
    entries = params[ :entries ].to_i
    entries = default_entries if ( entries <= 0 or entries > 500 )

    if ( 0..@columns.length ).include?( sort )

      # Valid sort order requested

      unless ( @columns[ sort ][ :sort_by ].nil? )
        order = @columns[ sort ][ :sort_by ].dup
      else
        order = @columns[ sort ][ :value_method ].to_s.dup
      end

    else

      # Default sort order - try to match DEFAULT_SORT_COLUMN against one of
      # the numbered columns.

      order = model::DEFAULT_SORT_COLUMN.dup

      @columns.each_index do | index |
        column = @columns[ index ]

        if ( column[ :value_method ].to_s == order or column[ :sort_by ].to_s == order )
          params[ :sort ] = index.to_s
          break
        end
      end
    end

    if ( params[ :direction ] == 'desc' )
      order << ' DESC'
    else
      order << ' ASC'
    end

    return { :page => page, :per_page => entries, :order => order }
  end

  # YUI tree form submission will present selected task IDs as a single string
  # in a comma separated list; the non-JS code does it properly as an array of
  # IDs. Sort this out by patching the params hash. Pass the item to patch
  # (e.g. ":user", ":control_panel"). An optional second parameter lets you
  # override the use of ":task_ids" for the second dimension "params" array
  # reference.
  #
  # [TODO]: Do this in the JS instead? Requires multiple hiddden INPUTs to
  # [TODO]: be dynamically created, one for each array entry; slow, complex
  #
  def appctrl_patch_params_from_js( sym, name = :task_ids )
    task_ids = (params[ sym ] || {} )[ name ] || []

    if ( task_ids.length == 1 && task_ids[ 0 ].is_a?( String ) )
      params[ sym ][ name ] = task_ids[ 0 ].split( ',' )
    end
  end

private

  #############################################################################
  # PRIVATE CODE
  #############################################################################

  # Set @current_user to the User of object of whoever is currently
  # logged in, or 'nil' if nobody is logged in. The Sessions Controller
  # sets up the 'user_id' field in the session hash.

  def appctrl_set_user
    @current_user ||= User.find_by_id( session[ :user_id ] )
  end

  # Ensure that we're logged in. If not, redirect to the Home page.

  def appctrl_confirm_user
    redirect_to( signin_path() ) unless @current_user
  end

  # If logged in but the current user has no name, assume a partial
  # sign in (perhaps the user closed their browser window or typed
  # in an explicit URL before submitting their User edit form) -
  # redirect back to that form.

  def appctrl_ensure_user_name
    if ( ( not @current_user.nil? ) and @current_user.name.empty? )
      redirect_to( edit_user_path( @current_user) )
    end
  end
end
