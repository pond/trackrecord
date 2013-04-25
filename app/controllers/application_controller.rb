########################################################################
# File::    application_controller.rb
# (C)::     Hipposoft 2007
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
    @record = model.constantize.new( nil, @current_user )
  end

  # Create a new object following submission of a 'create' view form.
  # Restricted users can't do this. Pass the model name as a string.

  def appctrl_create( model )
    return appctrl_not_permitted() if ( @current_user.restricted? )
    @record = model.constantize.new( params[ model.downcase ], @current_user )

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
  #
  def appctrl_admin_destroy( model )
    return appctrl_not_permitted() unless ( @current_user.admin? )
    appctrl_destroy( model )
  end

  # Destroy an object. Pass the model class (e.g. User). Access control
  # is left up to the caller (or use 'appctrl_admin_destroy' instead).
  # Optionally pass the path to redirect to upon success.
  #
  def appctrl_destroy( model, path = nil )
    begin
      model.destroy( params[ :id ] )

      flash[ :notice ] = "#{ model.model_name.human.capitalize } deleted"
      redirect_to( path || send( "#{ model.model_name.route_key }_path" ) )

    rescue => error
      flash[ :error ] = "Could not destroy #{ model.model_name.human }: #{ error }"
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

    # Set up some default sort and pagination data.

    default_sort      = -1 # "-1" => "unknown"
    default_direction = model::DEFAULT_SORT_DIRECTION.downcase
    default_entries   = 10
    default_page      = 1

    # Attempt to read user preferences for sorting and pagination in index
    # views for the given model. Note the heavy use of "try()" to tolerate
    # 'nil' values propagated through, e.g. due to no logged in user, or
    # a user with no control panel (not that this ought to ever happen).

    prefs_prefix      = "sorting.#{ model.name.downcase }."
    cp                = @current_user.try( :control_panel )
    cp_sort           = cp.try( :get_preference, "#{ prefs_prefix }sort"      )
    cp_direction      = cp.try( :get_preference, "#{ prefs_prefix }direction" )
    cp_entries        = cp.try( :get_preference, "#{ prefs_prefix }entries"   )

    # For each one, try to read from the parameters; or fall back to the user
    # settings; or fall back to the defaults. If the value so determined is
    # different from the user's current setting, then update that setting.

    sort = params[ :sort ].try( :to_i ) || cp_sort || default_sort
    cp.try( :set_preference, "#{ prefs_prefix }sort", sort ) unless ( cp_sort == sort )

    direction = params[ :direction ] || cp_direction || default_direction
    cp.try( :set_preference, "#{ prefs_prefix }direction", direction ) unless ( cp_direction == direction )

    entries = params[ :entries ].try( :to_i ) || cp_entries || default_entries
    entries = default_entries if ( entries <= 0 or entries > 500 )
    cp.try( :set_preference, "#{ prefs_prefix }entries", entries ) unless ( cp_entries == entries )

    # Establish a page number, then write the final determined values back into
    # the parameters hash as views or plugins may refer to these directly.

    page = params[ :page ].try( :to_i ) || default_page

    params[ :sort      ] = sort.to_s
    params[ :direction ] = direction
    params[ :entries   ] = entries.to_s
    params[ :page      ] = page.to_s

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

    if ( direction == 'desc' )
      order << ' DESC'
    else
      order << ' ASC'
    end

    return { :page => page, :per_page => entries, :order => order }
  end

  # Given a key for the params hash, construct a date from the value
  # associated with the key. If the key is not present or has an emtpy
  # value, or if any exception occurs trying to parse the date, the
  # function returns 'nil'; else it returns a Date object instance.
  #
  def appctrl_date_from_params( key )
    unless ( params[ key ].blank? )
      begin
        return Date.parse( params[ key ] )
      rescue
        # Do nothing - drop through to have-no-date case
      end
    end

    nil
  end

  # Return an array giving a start date and end date based on search
  # form submission data in the params hash. Pass a default start and
  # end date for the case where none has been provided in the params,
  # or the provided value is invalid.
  #
  def appctrl_dates_from_search( default_start, default_end )
    a = appctrl_date_from_params( :search_range_start ) || default_start
    b = appctrl_date_from_params( :search_range_end   ) || default_end

    a, b = b, a if ( a > b ) 

    return [ a, b ]
  end

  # Return an SQL fragment of the form "date-field >= :range_start AND
  # date-field <= bar :range_end" where the ranges are dates obtained
  # from "appctrl_dates_from_search" and 'date-field' is given as an
  # optional second input parameter. The return value includes the
  # ranges which you pass in using named parameter substitution when
  # the SQL fragment is included in a wider query.
  #
  # Pass the model being searched; it must support a 'used_range'
  # class method that returns a Range of years for all existant
  # instances in the database at the time of calling, for the field
  # that is to be searched. The second parameter is that field, or
  # if omitted, the model's USED_RANGE_COLUMN by default.
  #
  # Returns an array (anticipating parallel assignment by the caller)
  # with the SQl data, the start Date and the end Date of the range,
  # or an array of 'nil' if there is no usable search data in the
  # parameters hash (or it is being explicitly cleared).
  #
  # Intended side-effect: Makes sure that search parameters are cleared
  # out if an explicit 'search_cancel' params key has a value.
  #
  def appctrl_search_range_sql( model, field = nil )
    sql = range_start = range_end = nil

    field = model::USED_RANGE_COLUMN if ( field.nil? )

    unless ( params[ :search ].nil? )
      if ( ( params[ :search ].blank? and params[ :search_range_start ].blank? and params[ :search_range_end ].blank? ) or params[ :search_cancel ] )
        params.delete( :search )
        params.delete( :search_range_start )
        params.delete( :search_range_end )
      else
        range                  = model.used_range()
        range_start, range_end = appctrl_dates_from_search(
          Date.new( range.first    ),     # I.e. start year
          Date.new( range.last + 1 ) - 1  # I.e. start of year after end year, minus one day; that is, the last day of end year
        )

        # Since SQL date-only queries work on a 'start of the day' basis,
        # we do a ">=" start and a "<" end comparison, setting the end to
        # the beginning of the *next* day.

        range_end += 1

        sql = "#{ model.table_name }.#{ field } >= :range_start AND #{ model.table_name }.#{ field } < :range_end AND"
      end
    end

    [ sql, range_start, range_end ]
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
    if ( ( not @current_user.nil? ) and @current_user.name.blank? )
      redirect_to( edit_user_path( @current_user) )
    end
  end
end
