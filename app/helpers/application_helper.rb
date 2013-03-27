########################################################################
# File::    application_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Standard Rails application helper.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

module ApplicationHelper

  include TrackRecordSections

  #############################################################################
  # BASIC SUPPORT
  #############################################################################

  # Equivalent of 'h()', but returns '-' for nil or empty strings.

  def apphelp_h( value )
    return '-' if ( value.nil? or value.empty? )
    return h( value )
  end

  # Return a dynamic title based on the current request action and
  # controller.

  def apphelp_title
    action = h( action_name )
    ctname = h( controller.controller_name )

    if ( [ '', 'index', 'list' ].include?( action ) )
      title = ctname.capitalize
    else
      if ( action == 'home' )
        title = 'Home page'
      else
        ctname = ctname.singularize()

        if ( ctname == 'user' )
          title = "#{ action.capitalize } account"
        elsif ( ctname == 'task_import' )
          title = 'Bulk task import'
        else
          title = "#{ action.capitalize } #{ ctname }"
        end
      end
    end

    # Awkward special case
    title = "Enter timesheets" if ( title == "New timesheet" )

    return title
  end

  # Return data for the navigation bar ("slug").

  def apphelp_slug
    action = h( action_name )
    ctname = h( controller.controller_name )
    sep    = '&nbsp;&raquo;&nbsp;'
    slug   = link_to( 'Home page', home_path() ) << sep

    if ( ctname == 'users' and action == 'home' )
      slug = 'Home page'
    elsif ( ctname == 'sessions' and action == 'new' )
      slug << 'Sign in'
    elsif ( action == 'index' or action == 'list' )
      slug << apphelp_title()
    elsif ( ctname == 'reports' )
      if ( action == 'create' )
        slug << link_to( 'Reports', new_report_path() ) <<
                sep <<
                'Show report'
      else
        slug << 'Reports'
      end
    else
      slug << link_to( ctname.capitalize(), send( "#{ ctname }_path" ) ) <<
              sep <<
              apphelp_title()
    end

    return slug
  end

  # Return strings 'Yes' or 'No' depending on the value of the given
  # boolean quantity.
  #
  def apphelp_boolean( boolean )
    boolean ? 'Yes' : 'No'
  end

  # Return any flash messages using class names prefixed by "flash_",
  # with the suffix being the key name from the flash hash. The messages
  # are wrapped by a DIV with class 'messages'. If there are no messages
  # to show, an empty string is returned. Optionally pass an indent string
  # to add at the front of any non-empty line of output. If a non-empty
  # result is returned, note that it will be terminated by "\n\n".
  #
  def apphelp_flash_messages( indent = '' )
    output = ''

    flash.keys.each do | key |
      output << "<div class='flash_#{ h( key ) }'>#{ h( flash[ key ] ) }</div>"
    end

    unless ( output.empty? )
      output = indent + content_tag( :div, output, { :class => 'messages' } ) + "\n\n"
    end

    return output
  end

  # Return 'sign in' or 'you are signed in' text indicating current
  # status.

  def apphelp_sign_or_signed_in
    if ( @current_user )
      if ( @current_user.name.nil? or @current_user.name.empty? )
        signinfo = 'Creating new account'
      else
        signinfo = "You are signed in as #{ h( @current_user.name ) } &ndash; #{ link_to( 'sign out', signout_path() ) } "
      end
    else
      # The Application Controller forces redirection to the sign-in page
      # if the user isn't signed in.
      signinfo = "Please #{ link_to( 'sign in', signin_path() ) }"
    end

    return signinfo
  end

  # Output HTML suitable as a label to show whether or not the
  # given object is active or otherwise. The second parameter lets
  # you override the given object and force the generation of an
  # active (pass 'true') or inactive (pass 'false') label.

  def apphelp_commit_label( item, active = nil )
    active = item.active if ( active.nil? )
    active ? '<span class="item_active">Active</span>' :
             '<span class="item_inactive">Inactive</span>'
  end

  # Simple wrapper over 'pluralize' to return a string indicating a
  # number of hours mathematically rounded to two decimal places.

  def apphelp_hours( hours )
    pluralize( hours.precision( 2 ), 'hour' )
  end

  # Terse hours - precision 2, don't show ".0", no string suffix. If you want
  # a blank string instead of "0", pass "true" in the second parameter.

  def apphelp_terse_hours( hours, zero_is_blank = false )
    hours = hours.precision( 2 ).to_s.chomp( '0' ).chomp( '0' ).chomp( '.' )
    return '' if ( hours == '0' and zero_is_blank )
    return hours
  end

  # Pass a string representation of worked hours or a duration and a string
  # to show instead of "0.0", if that's the duration/worked hours value.
  # Optionally, pass in a string to use instead of an empty string, should
  # the duration/worked hours value be empty itself.

  def apphelp_string_hours( hours, alt_str, empty_str = nil )
    return ( empty_str ) if ( hours.empty? and not empty_str.nil? and not empty_str.empty? )
    return ( hours == '0.0' ? alt_str : hours )
  end

  # Standard date formatting; pass the date to format.

  def apphelp_date( date )
    return date.strftime( '%Y-%m-%d %H:%M:%S' )
  end

  #############################################################################
  # SELECTING THINGS
  #############################################################################

  # Return standard extra arguments for selection lists based on a
  # collection (its size is taken) and "multiple" flag

  def apphelp_extra_selection_args( collection, multiple )
    return multiple ? { :multiple => true, :size => [ collection.size, 10 ].min } : {}
  end

  # Run 'collection_select' for the given form with the given arguments
  # for the field name of the target object to be updated, the collection,
  # the field from within that collection to use for the values to actually
  # set in the target object and the field from within that collection to
  # use for the values displayed to the user.
  #
  # A sixth optional boolean parameter, defaulting to 'true', says whether
  # or not the selection list should allow multiple selections (for this,
  # pass 'true'). The function takes care of working out how tall to make
  # the selection list (the 'size' parameter) internally, which is really
  # the only reason to call here rather than calling 'collection_select'
  # directly.
  #
  # Single selection items will include blank entries.

  def apphelp_collection_select( form, objfield, collection, colsetfield, colseefield, multiple = true )
    return form.collection_select(
      objfield,
      collection,
      colsetfield,
      colseefield,
      multiple ? {} : { :include_blank => 'None' },
      apphelp_extra_selection_args( collection, multiple )
    )
  end

  # As apphelp_collection_select, but runs 'select' rather than
  # 'collection_select'. The parameters are adjusted accordingly.

  def apphelp_select( form, objfield, choices, multiple = true )
    return form.select(
      objfield,
      choices,
      {},
      apphelp_extra_selection_args( choices, multiple )
    )
  end

  # Return HTML suitable for an edit form, providing a grouped list of
  # projects that can be assigned to something. The list is grouped by
  # customer in default customer sort order, along with a 'None' entry
  # for unassigned projects. Pass an ID for the select list, a name for
  # the select list, and an ID to match within the list to have one of
  # the entries selected (or omit for no pre-selected item). Pass an
  # optional fourth parameter of "true" to include a "none" entry, else
  # exclude it (exclusion is the default behaviour).

  def apphelp_project_selector( select_id, select_name, match, include_none = false )

    customers = []

    # Add the "none" entry; but of a hack, this... :-(

    if ( include_none )
      dummy_project           = Project.new
      dummy_project.id        = ''
      dummy_project.title     = 'None'

      dummy_customer          = Customer.new
      dummy_customer.id       = ''
      dummy_customer.title    = 'None'
      dummy_customer.projects = [ dummy_project ]

      customers.push( dummy_customer )
    end

    # Create a dummy customer for the unassigned projects.

    dummy_customer          = Customer.new
    dummy_customer.title    = 'No assigned customer'
    dummy_customer.projects = Project.active.unassigned

    customers.push( dummy_customer ) unless ( dummy_customer.projects.empty? )

    # Find all customers and loop through, adding those that have at least
    # one assigned project to the 'customers' array.

    Customer.active.each do | customer |
      customers.push( customer ) unless ( customer.projects.active.count.zero? )
    end

    return 'There are no active projects.' if ( customers.empty? )

    data = "<select id=\"#{ select_id }\" name=\"#{ select_name }\">"
    data << option_groups_from_collection_for_select(
      customers, # Use customers for groups
      :projects, # A customer's "projects" method returns its project list
      :title,    # Use the customer title for the group labels
      :id,       # A project's "id" method returns the value for an option tag
      :title,    # A project's "title" method is used for the option contents
      match      # Match this ID for the selected option item
    )
    return data << '</select>'
  end

  # Return HTML representing a human-readable list of the given
  # objects, as links to titles for the objects. To list a
  # different field, provide the field name as a symbol in the
  # optional second parameter.

  def apphelp_object_list( objects, field = :title )
    return 'None' if ( objects.nil? or objects.empty? )

    objects.collect! do | object |
      link_to( h( object.send( field ) ), object )
    end

    return objects.join( ', ' )
  end

  #############################################################################
  # LIST VIEWS
  #############################################################################

  # Construct a header row for a list table, returning HTML for it. The table
  # outer definition must be included externally. To define the row contents,
  # pass an array of hashes. Each array entry corresponds to a cell in the row,
  # built in order of appearance in the array. The hashes can contain optional
  # property "header_align" to override the row alignment for that cell; the
  # property's value is used directly as a TH "align" value.
  #
  # Each hash must include property "header_text" giving the heading text for
  # that cell. The text is placed in the cell wrapped up in an HTML link which
  # will re-fetch the list view with modified search parameters. To achieve
  # this requires a second mandatory input parameter, which is the name of the
  # model being listed, singular, lower case (e.g. "user").
  #
  # A blank header cell is placed at the end of the row to appear above an
  # actions column if the third mandatory parameter is non-nil. If nil, no room
  # is made for an actions column.
  #
  # See also apphelp_list_row.
  #
  # E.g.:
  #
  #   apphelp_list_header(
  #     [
  #       { :header_text => 'User name' },
  #       { :header_text => 'Age', :header_align => 'center' },
  #       { :header_text => 'E-mail address' }
  #     ],
  #     'users_path'
  #   )

  def apphelp_list_header( structure, model, actions_method )
    output = "        <tr valign=\"middle\" align=\"left\" class=\"info\">\n"

    structure.each_index do | index |
      entry      = structure[ index ]
      align      = entry[ :header_align ]
      sort_class = nil

      if ( params[ :sort ] == index.to_s )
        if ( params[ :direction ] == 'desc' )
          sort_class = "sorted_column_desc"
        else
          sort_class = "sorted_column_asc"
        end
      end

      output << "          <th"
      output << " class=\"#{ sort_class }\"" unless ( sort_class.nil? )

      if ( align.nil? )
        output << ">" if ( align.nil? )
      else
        output << " align=\"#{ align }\">"
      end

      if ( entry[ :value_method ] or entry[ :sort_by ] )
        output << apphelp_list_header_link( model, entry[ :header_text ], index )
      else
        output << entry[ :header_text ]
      end

      output << "</th>\n"
    end

    output << "          <th width=\"1\">&nbsp;</th>\n" unless ( actions_method.nil? )
    return ( output << "        </tr>\n" )
  end

  # Construct a body row for a list table, returning HTML for it. The table
  # outer definition must be included externally. To define the row contents,
  # pass an array of hashes. Each array entry corresponds to a cell in the
  # row, built in order of appearance in the array. The hashes can contain
  # optional property "value_align" to override the row alignment for that
  # cell; the property's value is used directly as a TD "align" value.
  #
  # Each hash must include property "value_method". This method will be
  # invoked on the object given in the second function input parameter and
  # must return a displayable value for the cell. The output is made safe
  # by wrapping with a call to "h()" automatically.
  #
  # The third input parameter is the name of a helper method which will be
  # invoked with the current item as a parameter. It must return the names
  # of actions permitted for that item, in an array. Actions will be placed
  # in the final cell on the row as normal links. If the parameter is 'nil',
  # no actions cell will be added onto the rows.
  #
  # Since models can't always generate what you want (e.g. they don't have
  # access to helpers, so creating values with associations' "show" views
  # linked to is difficult), you can specify property "value_helper". This
  # helper method will be called and passed the item. Its return value is
  # used instead of the value method, which won't be called and can be
  # omitted if a helper is being used instead. HELPER TEXT IS *NOT* WRAPPED
  # BY A CALL TO "h()" - value helpers MUST do this themselves.
  #
  # See also apphelp_list_header.
  #
  # E.g.:
  #
  #   apphelp_list_row(
  #     [
  #       { :value_method => 'name' },
  #       { :value_method => 'age', :value_align => 'center' },
  #       { :value_method => 'email_as_link' } # Custom method in User model
  #     ],
  #     User.find( :first )
  #   )

  def apphelp_list_row( structure, item, actions_method )
    output = "        <tr valign=\"top\" align=\"left\" class=\"#{ cycle( 'even', 'odd' ) }\">\n"

    # Handle the item columns first

    structure.each_index do | index |
      entry = structure[ index ]
      align = entry[ :value_align ]

      output << "          <td"

      if ( align.nil? )
        output << ">" if ( align.nil? )
      else
        output << " align=\"#{ align }\">"
      end

      method = entry[ :value_method ]
      helper = entry[ :value_helper ]

      if ( helper )
        output << send( helper, item )
      else

        # Restricted users can only edit their own account. Since they are not
        # allowed to list other users on the system, the list view is disabled
        # for them, so there can never be in-place editors in that case. For
        # any other object type, restricted users have no edit permission. The
        # result? Disable all in-place editors for restricted users.

        in_place = entry[ :value_in_place ] && @current_user.privileged?

        if ( in_place )
          output << safe_in_place_editor_field( item, method )
        else
          output << h( item.send( method ) )
        end
      end

      output << "</td>\n"
    end

    # Add the actions cell?

    unless ( actions_method.nil? )
      actions = send( actions_method, item ) || []
      output << "          <td class=\"list_actions\" nowrap=\"nowrap\">\n"
      actions.each do | action |
        output << "            "
        output << link_to( action.humanize, { :action => action, :id => item.id } )
        output << "\n"
      end
      output << "          </td>\n"
    end

    return ( output << "        </tr>\n" )
  end

  # Support function for apphelp_list_header.
  #
  # Returns an HTML link based on a URL acquired by calling "models_path",
  # where "models" comes from pluralizing the given lower case singular
  # model name, wrapping the given link text (which will be protected in turn
  # with a call to "h(...)"). Pass also the index of the column in the list
  # structure. Generates a link with query string attempting to maintain or
  # set correctly the sort and pagination parameters based on the current
  # request parameters and given column index.
  #
  # E.g.:
  #
  #   apphelp_list_header_link( 'users_path', 'User name', 0 )

  def apphelp_list_header_link( model, text, index )

    # When generating the link, there is no point maintaining the
    # current page number - reset to 1. Do maintain the entries count.

    entries   = ''
    entries   = "&entries=#{ params[ :entries ] }" if params[ :entries ]

    # For the direction, if the current sort index in 'params' matches
    # the index for this column, the link should be used to toggle the
    # sort order; if currently on 'asc', write 'desc' and vice versa.
    # If building a link for a different column, default to 'asc'.

    direction = ''

    if ( params[ :sort ] == index.to_s && params[ :direction ] == 'asc' )
      direction = '&direction=desc'
    else
      direction = '&direction=asc'
    end

    # Get the base URL using the caller-supplied method and assemble the
    # query string after it.

    base = send( "#{ model.pluralize }_path" )
    url  = "#{ base }?sort=#{ index }#{ direction }&page=1#{ entries }"

    unless ( params[ :search ].nil? or params[ :search ].empty? )
      url << "&search=#{ params[ :search ] }"
    end

    return link_to( h( text ), url )
  end

  # Column formatting helper for creation dates. Pass an object with a
  # created_at method. The value returned is used for display.

  def apphelp_created_at( obj )
    return apphelp_date( obj.created_at )
  end

end
