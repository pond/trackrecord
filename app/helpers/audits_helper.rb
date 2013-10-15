########################################################################
# File::    audits_helper.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Support functions for views related to audit data. See
#           controllers/audits_controller.rb for more.
# ----------------------------------------------------------------------
#           20-Jan-2008 (ADH): Created.
########################################################################

module AuditsHelper

  # List view helper - display the type of change. Combines the action
  # with the auditable type (the name of the model object on which the
  # operation was performed), then converts the auditable type into an
  # actual model class (via "constantize"). Uses the auditable ID to
  # extract information specific to the object type and adds to the
  # column output to include that data where possible. All exceptions
  # caught to cope with deleted items etc. not being found.

  def audithelp_type_of_change( record )
    type = begin
      record.auditable_type.constantize.model_name.human
    rescue
      record.auditable_type.downcase
    end

    type   = 'permitted OpenID' if type == 'permittedopenid'
    output = "#{ record.action.capitalize() } #{ h( type ) }"

    begin
      objtype = record.auditable_type.constantize()
      objinst = objtype.find_by_id( record.auditable_id )

      case ( record.auditable_type )
        when 'User'
          return append_link( output, "'#{ h( objinst.name ) }'", record )

        when 'Task', 'Project', 'Customer'
          return append_link( output, "'#{ h( objinst.title ) }'", record )

        when 'Timesheet'
          return append_link( output << ' for week', "#{ h( objinst.week_number ) }, #{ h( objinst.year ) }", record )

        else
          return output
      end

    rescue
      return output

    end
  end

  # List view helper - user name of person responsible for change

  def audithelp_user_name( record )
    return to_descriptive_s( record.user ? record.user.name : nil )
  end

  # List view helper - change details

  def audithelp_changes( record )
    type    = record.auditable_type
    changes = record.audited_changes

    if ( changes.blank? )
      if ( type == 'Timesheet' )
        return 'Added or removed rows, or edited hours within rows'
      else
        return 'No other details available'
      end
    end

    output  = '<table class="list audit_changes">'
    output << '<tr><th class="audit_changes_field">Field</th><th class="audit_changes_from">From</th><th class="audit_changes_to">To</th></tr>'

    changes.keys.each do | key |
      cdata = changes[ key ]

      if ( cdata.instance_of?( Array ) )
        cfrom = to_descriptive_s( cdata[ 0 ] )
        cto   = to_descriptive_s( cdata[ 1 ] )
      else
        cfrom = '&ndash;'.html_safe()
        cto   = cdata.to_s()
      end

      # Try to get clever :-) and see if we have "[foo_]id" in a string. If
      # so, extract "foo" and see if the item can be found.

      array = key.split( '_' )

      if ( array.size > 1 )
        check = array.pop()

        if ( check == 'id' )
          type = array[ 0 ].capitalize

          if ( type == 'User' or type == 'Project' or type == 'Customer' or type == 'Task' )
            field = ( type == 'User' ) ? 'name' : 'title'

            begin
              const = type.constantize

              if ( cfrom.to_i.to_s == cfrom )
                item  = const.find_by_id( cfrom )
                cfrom = "#{ cfrom } (#{ item[ field ] })" unless ( item.nil? )
              end

              if ( cto.to_i.to_s == cto )
                item = const.find_by_id( cto )
                cto  = "#{ cto } (#{ item[ field ] })" unless ( item.nil? )
              end
            rescue
              # Do nothing - just ignore errors
            end
          end
        end
      end

      output << "<tr><td>#{ h( key ) }</td><td>#{ h( cfrom ) }</td><td>#{ h( cto ) }</td></tr>"
    end

    return ( output << '</table>' ).html_safe
  end

private

  # Support audithelp_type_of_change - append to the given output string, the
  # given text expressed as a link to the item identified by the given record.

  def append_link( output, text, record )
    return ( output << " " << link_to(
        text.html_safe,
        {
          :controller => record.auditable_type.downcase.pluralize,
          :action     => 'show',
          :id         => record.auditable_id
        }
      )
    ).html_safe()
  end

  # A descriptive to_s; indicates empty or nil strings. Result is run through
  # 'h()' so is safe for use in HTML output; added bonus of *not* needing to
  # convert the input parameter to a string first.

  def to_descriptive_s( str )
    return '(Nil)'   if str.nil?
    return '(Empty)' if str == ''
    return h( str )
  end
end
