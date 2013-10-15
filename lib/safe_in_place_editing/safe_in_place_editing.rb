########################################################################
# File::    safe_in_place_editing.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Safe, lockable in-place editing - controller support.
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Created.
########################################################################

module SafeInPlaceEditing

  def self.included( base ) # :nodoc:
    base.extend( ClassMethods )
  end

  module ClassMethods

    # Exact API equivalent of in_place_edit_for, except:
    #
    # - Runs all user data through "ERB::Util::html_escape" when sending it to
    #   the view to avoid associated vulnerabilities with otherwise-unescaped
    #   user-supplied data; the current InPlaceEditing plugin does this too,
    #   albeit using "CGI::escapeHTML" for some reason.
    #
    # - Supports optimistic locking if a lock_version CGI parameter is
    #   supplied, by explicitly checking the version being updated.
    #
    # - Explicitly catches errors and returns them as 500 status codes
    #   with a plain text message regardless of Rails environment.
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

        # Call "touch" to make sure the item is modified even if the user has
        # actually just submitted the form with an unchanged variable. This
        # makes sure that Rails sees the object as 'dirty' and saves it. For
        # objects with lock versions, that means the lock version always
        # increments. The JavaScript code has to assume such an increment and
        # has no clear way to know if it doesn't happen; we could dream up
        # something complex but simpler just to ensure Rails is in step.
        #
        # In the worst possible case, JavaScript and Rails end up out of step
        # with the lock version and the user gets told there's a mismatch. A
        # page reload later and everything is sorted out.

        success = @item.update_attribute( attribute, params[ :value ] )
        success = @item.touch if ( success && ! lock_version.nil? && @item.lock_version.to_s == lock_version )

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
