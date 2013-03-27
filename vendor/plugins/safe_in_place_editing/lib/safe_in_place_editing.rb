########################################################################
# File::    safe_in_place_editing.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Safe, lockable in-place editing - controller support.
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Created.
########################################################################

module SafeInPlaceEditing

  def self.included( base )
    base.extend( ClassMethods )
  end

  module ClassMethods

    # Exact API equivalent of in_place_edit_for, except:
    #
    # (1) Prevents XSS vulnerabilities by escaping the user-supplied value
    #     which it renders back to the AJAX code. Values are always escaped
    #     since it's highly unlikely that you'd want to have the user input
    #     HTML and send that straight back to the view, so chances are you
    #     need custom code anyway (e.g. to parse user input via the Textile
    #     or Markaby engines and render the parsing results instead).
    #
    # (2) Supports optimistic locking if a lock_version CGI parameter is
    #     supplied, by explicitly checking the version being updated.
    #
    # (3) Explicitly catches errors and returns them as 500 status codes
    #     with a plain text message regardless of Rails environment.
    #
    # See safe_in_place_editor and safe_in_place_editor_field inside file
    # "safe_in_place_editing_helper.rb" for the counterpart helper functions.
    #
    # The Prototype library getText function must be patched as described in
    # the README rationale; see public/javascripts/safe_in_place_editing.js.

    def safe_in_place_edit_for( object, attribute, options = {} )
      define_method( "set_#{object}_#{attribute}" ) do
        safe_in_place_edit_backend( object, attribute, options )
      end
    end
  end

private

  # Back-end for "safe_in_place_edit_for" - the actual invoked implementation
  # of the dynamically created functions.

  def safe_in_place_edit_backend( object, attribute, options )
    @item = object.to_s.camelize.constantize.find( params[ :id ] )

    lock_version = nil
    lock_version = @item.lock_version.to_s if ( @item.respond_to?( :lock_version ) )

    if ( params.include?( :lock_version ) and lock_version != params[ :lock_version ] )
      render( { :status => 500, :text => "Somebody else already edited this #{ object.to_s.humanize.downcase }. Reload the page to obtain the updated version." } )
      return
    else
      begin
        success = @item.update_attribute( attribute, params[ :value ] )

        # JavaScript code has to assume an increment of lock_version for
        # those models which use locking, but Rails may not actually save the
        # record if it thinks the attribute value is unchanged. Force a save
        # in such cases. It's easier than trying to convince JavaScript to
        # decide whether or not an attribute value has changed using precisely
        # the same (unknown, private) semantics as the Rails framework!
        #
        if ( success && ! lock_version.nil? && @item.lock_version.to_s == lock_version )
          success = @item.save!
#          success = @item.increment!( :lock_version )
        end

        raise "Unable to save changes to database" unless ( success )

      rescue => error
        render( { :status => 500, :text => error.message } )
        return

      end
    end

    value = @item.send( attribute )

    if ( ( value.is_a? TrueClass ) || ( value.is_a? FalseClass ) )
      value = value ? 'Yes' : 'No'
    else
      value = ERB::Util::html_escape( value.to_s )
    end

    render( { :text => value } )
  end
end
