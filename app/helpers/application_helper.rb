########################################################################
# File::    application_helper.rb
# (C)::     Hipposoft 2007
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
    return '-'.html_safe() if ( value.blank? )
    return h( value )
  end

  # Return an internationalised version of the web site's name.
  #
  def apphelp_site_name
    t( :'uk.org.pond.trackrecord.site_name' )
  end

  # Return an internationalised version of the given action name. If 'true'
  # is passed in the second parameter, a default fallback of the humanized
  # version of the non-internationalised action name will be chosen. If this
  # parameter is omitted or 'false' is given, the I18n engine's "missing token"
  # message is returned instead (no default string is used).
  #
  def apphelp_action_name( action, use_default = false )
    options = use_default ? { :default => action.to_s.humanize } : {}
    t( "uk.org.pond.trackrecord.action_names.#{ action }", options )
  end

  # Return a brief internationalised version of the given action. Only a
  # limited subset is supported (see the "brief_action_names" list in
  # "config/locales/en.yml" for details). Intended for list views typically.
  #
  def apphelp_brief_action_name( action )
    t( "uk.org.pond.trackrecord.brief_action_names.#{ action }" )
  end

  # Return an internationalised heading appropriate for a page handling the
  # current action for the current controller, or the given controller and
  # optional given action name. If you want to use a default string, pass it
  # in the optional third parameter. Headings like this can be (and are) also
  # used as descriptive action link text.
  #
  def apphelp_heading( ctrl = controller, action = nil, default = nil )
    action ||= ctrl.action_name

    t(
      "uk.org.pond.trackrecord.controllers.#{ ctrl.controller_name }.action_title_#{ action }",
      :default => default
    )
  end

  # Return an internationalised title appropriate for a page handling the
  # current action for the current controller, or the given controller.
  #
  def apphelp_title( ctrl = controller )
    "#{ apphelp_site_name }: #{ apphelp_heading( ctrl ) }"
  end

  # Shortcut for long references to "uk.org.pond.trackrecord.generic_messages"
  # when reading generic messages from the locale file. Pass the message token
  # part (e.g. "yes", "no", "confirmation"). Only useful for basic messages
  # which require no parameter substitution or default lookup values.
  #
  def apphelp_generic( message_name )
    I18n::t( "uk.org.pond.trackrecord.generic_messages.#{ message_name }" )
  end

  # Return a controller view hint, based on looking up "view_<foo>" in the
  # locale file for the given value of "<foo>" (as a string or symbol). The
  # controller handling the current request is consulted by default, else
  # pass a reference to the controller of interest in the optional second
  # parameter. If the hint includes subsitution tokens, pass them in an
  # optional third parameter as a hash.
  #
  def apphelp_view_hint( hint_name, ctrl = controller, substitutions = {} )
    apphelp_prefixed( :view, hint_name, ctrl, substitutions )
  end

  # As apphelp_view_hint, but looks for "flash_<foo>". Intended for flash
  # messages; the "flash_" prefix should keep string meanings more obvious
  # inside locale files. Pass the flash key to set (e.g. ":error" or
  # ":notice"), the name to look up ("<foo>"), then the optional controller
  # / nil and substitution hash. On exit, the flash is set and the string
  # that was used is returned.
  #
  # IMPORTANT: This sets the flash directly, expecting a redirection to happen
  # next. If instead you're just going to render something in *this* request,
  # you must use "apphelp_flash_now". Otherwise, your flash message will appear
  # on both the current, rendered page, and the next fetched page.
  #
  def apphelp_flash( key, flash_name, ctrl = controller, substitutions = {} )
    flash[ key ] = apphelp_prefixed( :flash, flash_name, ctrl, substitutions )
  end

  # As apphelp_flash, but for use when you're about to render content within
  # this request, rather than redirect.
  #
  def apphelp_flash_now( key, flash_name, ctrl = controller, substitutions = {} )
    flash.now[ key ] = apphelp_prefixed( :flash, flash_name, ctrl, substitutions )
  end

  # Back-end for apphelp_view_hint and apphelp_flash (along with possibly
  # others). Looks up "uk.org.pond.trackrecord.controllers.[n].[p]_[s]", with
  # the returned string marked HTML-safe, in the locale files; where [n] is a
  # controller name, [p] a prefix string and [s] a suffix string. Pass the
  # prefix string/symbol, suffix string/symbol, then optionally the
  # controller (defaults to current request handling controller, or pass 'nil'
  # for the same result) and optionally any token substitutions as a hash.
  #
  def apphelp_prefixed( prefix, suffix, ctrl = controller, substitutions = {} )
    ctrl ||= controller

    I18n::t(
      "uk.org.pond.trackrecord.controllers.#{ ctrl.controller_name }.#{ prefix }_#{ suffix }",
      substitutions
    ).html_safe()
  end

  # Return data for the navigation bar ("slug").

  def apphelp_slug
    action = h( action_name )
    ctname = h( controller.controller_name )
    sep    = '&nbsp;&raquo;&nbsp;'.html_safe()
    slug   = link_to( 'Home', home_path() ) << sep

    if ( ctname == 'users' and action == 'home' )
      slug = 'Home'
    elsif ( ctname == 'sessions' and ( action == 'new' || action == 'create' ) )
      slug << 'Sign in'
    elsif ( action == 'index' or action == 'list' or ctname == 'timesheet_force_commits' )
      slug << apphelp_heading()
    elsif ( ctname == 'reports' )
      slug << link_to( 'Reports', new_user_saved_report_path( @current_user ) ) <<
              sep <<
              'Show report'
    elsif ( ctname == 'saved_reports' )
      slug << link_to( 'Reports', new_user_saved_report_path( @current_user ) ) <<
              sep <<
              apphelp_heading()
    else
      slug << link_to( ctname.capitalize(), send( "#{ ctname }_path" ) ) <<
              sep <<
              apphelp_heading()
    end

    return slug
  end

  # Return 'yes' or 'no', internationalised, according to the given value,
  # which is evaluated as (or should already be) a boolean. Remember that in
  # Ruby the boolean evaluation of certain types can be unexpected - e.g.
  # integer zero is not "nil", so it evaluates to 'true' in a boolean context.
  #
  def apphelp_boolean( bool )
    apphelp_generic( bool ? :yes : :no )
  end

  # Return any flash messages using class names prefixed by "flash_",
  # with the suffix being the key name from the flash hash. The messages
  # are wrapped by a DIV with class 'messages'. If there are no messages
  # to show, an empty string is returned. Optionally pass an indent string
  # to add at the front of any non-empty line of output. If a non-empty
  # result is returned, note that it will be terminated by "\n\n". Result
  # contains HTML but is safe and marked as such.
  #
  def apphelp_flash_messages( indent = '' )
    output = ''

    flash.keys.each do | key |
      output << "<div class='flash_#{ h( key ) }'>#{ h( flash[ key ] ) }</div>"
    end

    unless ( output.empty? )
      output = "#{ indent }#{ content_tag( :div, output.html_safe(), { :class => 'messages' } ) }\n\n"
    end

    return output.html_safe()
  end

  # Return 'sign in' or 'you are signed in' text indicating current
  # status.

  def apphelp_sign_or_signed_in
    if ( @current_user )
      if ( @current_user.name.nil? or @current_user.name.empty? )
        signinfo = 'Creating new account'
      else
        signinfo = "#{ h( @current_user.name ) } &ndash; #{ link_to( 'sign out', signout_path() ) } "
      end
    else
      # The Application Controller forces redirection to the sign-in page
      # if the user isn't signed in.
      signinfo = "Please #{ link_to( 'sign in', signin_path() ) }"
    end

    return signinfo.html_safe()
  end

  # Output HTML suitable as a label to show whether or not the
  # given object is active or otherwise. The second parameter lets
  # you override the given object and force the generation of an
  # active (pass 'true') or inactive (pass 'false') label.

  def apphelp_commit_label( item, active = nil )
    active = item.active if ( active.nil? )

    return content_tag(
      :span,
      active ? 'Active' : 'Inactive',
      { :class => ( active ? :active : :inactive ) }
    )
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
    return ''.html_safe() if ( hours == '0' and zero_is_blank )
    return hours
  end

  # Pass a string representation of worked hours or a duration and a string
  # to show instead of "0.0", if that's the duration/worked hours value.
  # Optionally, pass in a string to use instead of an empty string, should
  # the duration/worked hours value be empty itself.

  def apphelp_string_hours( hours, alt_str, empty_str = nil )
    return ( empty_str ) if ( hours.empty? and not empty_str.blank? )
    return ( hours == '0.0' ? alt_str : hours )
  end

  # Standard date formatting; pass the date to format. This can be either a
  # date-only Date class, or a date-with-time DateTime class. Returns HTML,
  # marked HTML safe.
  #
  def apphelp_date( date )
    date_strfmt = I18n::t( 'uk.org.pond.trackrecord.generic_messages.date' )
    date_format = "<span class=\"nowrap\">#{ date_strfmt }</span>"

    if ( date.is_a?( Date ) )
      return date.strftime( date_format ).html_safe()
    else
      time_strfmt = I18n::t( 'uk.org.pond.trackrecord.generic_messages.time' )
      time_format = "<span class=\"nowrap\">#{ time_strfmt }</span>"
      return date.strftime(
        I18n::t(
          "uk.org.pond.trackrecord.generic_messages.date_and_time",
          { :date => date_format, :time => time_format }
        )
      ).html_safe()
    end
  end

  # As "apphelp_date", but plain text only (done as a separate method
  # rather than via extra parameters and conditionals for speed).
  #
  def apphelp_date_plain( date )
    date_strfmt = I18n::t( 'uk.org.pond.trackrecord.generic_messages.date' )

    if ( date.is_a?( Date ) )
      return date.strftime( date_strfmt )
    else
      time_strfmt = I18n::t( 'uk.org.pond.trackrecord.generic_messages.time' )
      return date.strftime(
        I18n::t(
          "uk.org.pond.trackrecord.generic_messages.date_and_time",
          { :date => date_strfmt, :time => time_strfmt }
        )
      )
    end
  end

  # As "apphelp_date", but returns a representation of a range of two
  # dates, inclusive.
  #
  def apphelp_range( range )
    I18n::t(
      "uk.org.pond.trackrecord.generic_messages.range",
      { :start => apphelp_date( range.min ), :finish => apphelp_date( range.max ) }
    ).html_safe()
  end

  # As "apphelp_date_plain", but returns a representation of a range of
  # two dates, inclusive.
  #
  def apphelp_range_plain( range )
    I18n::t(
      "uk.org.pond.trackrecord.generic_messages.range",
      { :start => apphelp_date_plain( range.min ), :finish => apphelp_date_plain( range.max ) }
    )
  end
    
  # For an object with a 'title', 'code' and 'description' attribute, make
  # a link to that object showing its title as the link text, with a link
  # title attribute consisting of the code and description (where either,
  # both or neither may be an empty string or even nil). Returns the link.
  #
  def apphelp_augmented_link( obj )
    title = ""
    title << obj.code unless obj.try( :code ).blank?
    title << "\n" unless title.empty? or obj.try( :description ).blank?
    title << obj.description unless obj.try( :description ).blank?

    content_tag(
      :span,
      link_to( obj.title, obj ),
      :title => title
    )
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

    Customer.active.all.each do | customer |
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
    return ( data << '</select>' ).html_safe()
  end

  # Return HTML representing a human-readable list of the given
  # objects, as links to titles for the objects. To list a
  # different field, provide the field name as a symbol in the
  # optional second parameter.

  def apphelp_object_list( objects, field = :title )
    return 'None' if ( objects.blank? )

    objects.collect! do | object |
      link_to( h( object.send( field ) ), object )
    end

    return objects.join( ', ' ).html_safe()
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
  # method to use for the 'index' view - e.g. "users_path" or (for an example
  # nested resource) "user_saved_reports_path".
  #
  # A blank header cell is placed at the end of the row to appear above an
  # actions column if the third optiona parameter is non-nil. If nil, no room
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
  #
  def apphelp_list_header( structure, index_method, actions_method = nil )
    output = "        <tr class=\"info\">\n"

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
        output << " style=\"text-align: #{ align }\">"
      end

      if ( entry[ :value_method ] or entry[ :sort_by ] )
        output << apphelp_list_header_link( index_method, entry[ :header_text ], index )
      else
        output << entry[ :header_text ]
      end

      output << "</th>\n"
    end

    output << "          <th class=\"spacer\">&nbsp;</th>\n" unless ( actions_method.nil? )
    return ( output << "        </tr>\n" ).html_safe()
  end

  # Support function for apphelp_list_header.
  #
  # Returns an HTML link based on a URL acquired by calling the given index
  # method (e.g. "users_path" or "user_saved_reports_path") and wrapping the
  # link text given in the second parameter with a link to the result of the
  # index method call. Pass also the index of the column in the list structure.
  # Generates a link with query string attempting to maintain or  set correctly
  # the sort and pagination parameters based on the current request parameters
  # and given column index.
  #
  # E.g.:
  #
  #   apphelp_list_header_link( 'users_path', 'User name', 0 )
  #
  def apphelp_list_header_link( index_method, text, index )

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

    base = send( index_method )
    url  = "#{ base }?sort=#{ index }#{ direction }&page=1#{ entries }"

    unless ( ( params[ :search ].blank? and params[ :search_range_start ].blank? and params[ :search_range_end ].blank? ) or params[ :search_cancel ] )
      hash = {
        :search             => params[ :search             ],
        :search_range_start => params[ :search_range_start ],
        :search_range_end   => params[ :search_range_end   ],
      }

      url << '&' << hash.to_query()
    end

    return link_to( text, url )
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
  # The fourth input parameter is optional. If present and 'true', buttons
  # linking to auto-generated reports relevant for the resource at hand are
  # added in the actions area. For example, a task would link to a report
  # for hours on just that task; a user to a user report over all tasks;
  # a project to all tasks in that project and so-on.
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
  #
  def apphelp_list_row( structure, item, actions_method, with_reports = false )
    output = "        <tr class=\"#{ cycle( 'even', 'odd' ) }\">\n"

    # It's assumed that admins can always modify things, but otherwise,
    # we will only allow in-place editors if the model instance can tell
    # us that editing is allowed by the current user.

    can_edit = @current_user.admin? || (
                 item.respond_to?( :can_be_modified_by? ) &&
                 item.can_be_modified_by?( @current_user )
               )

    # Handle the item columns first

    structure.each_index do | index |
      entry = structure[ index ]
      align = entry[ :value_align ]

      output << "          <td"

      if ( align.nil? )
        output << ">" if ( align.nil? )
      else
        output << " style=\"text-align: #{ align }\">"
      end

      method = entry[ :value_method ]
      helper = entry[ :value_helper ]

      if ( helper )
        output << send( helper, item )
      else

        if ( can_edit && entry[ :value_in_place ] )
          output << safe_in_place_editor_field( item, method )
        else
          value   = item.send( method )
          safestr = ( value === true or value === false ) ?
                                 apphelp_boolean( value ) :
                                               h( value )

          output << safestr
        end
      end

      output << "</td>\n"
    end

    # Add the actions cell?

    unless ( actions_method.nil? )
      actions = send( actions_method, item ) || []
      output << "          <td class=\"list_actions\">\n"
      actions.each do | action |
        output << "            "
        if ( action.class == Hash )
          title = apphelp_brief_action_name( action[ :title ] )
          output << link_to( title, action[ :url ] % item.id.to_s )
        else
          title = apphelp_brief_action_name( action )
          output << link_to( title, { :action => action, :id => item.id } )
        end
        output << "\n"
      end

      if ( with_reports )
        output << render(
                          {
                            :partial => 'shared/report_button',
                            :locals  =>
                            {
                              :user => @current_user,
                              :item => item
                            }
                          }
                        ).gsub( /^/, '            ' )
      end

      output << "          </td>\n"
    end

    return ( output << "        </tr>\n" ).html_safe()
  end

  # Column formatting helper for creation dates. Pass an object with a
  # created_at method. The value returned is used for display.

  def apphelp_created_at( obj )
    return apphelp_date( obj.created_at )
  end

end
