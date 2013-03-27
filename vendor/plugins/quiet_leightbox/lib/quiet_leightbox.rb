########################################################################
# File::    quiet_leightbox.rb
# (C)::     Hipposoft 2009
#
# Purpose:: Only include Leightbox components if a view requires them.
# ----------------------------------------------------------------------
#           16-Nov-2009 (ADH): Created.
########################################################################

module QuietLeightbox
  mattr_accessor :default_options

  # Define the "uses_leightbox" controller method.
  #
  module ClassMethods
    def uses_leightbox( filter_options = {} )
      proc = Proc.new do | c |
        c.instance_variable_set( :@uses_leightbox, true )
      end

      before_filter( proc, filter_options )
    end
  end

  # Add in the class methods and establish the helper calls when the module
  # gets included.
  #
  def self.included( base )
    base.extend( ClassMethods  )
    base.helper( QuietLeightboxHelper )
  end

  # The helper module - methods for use within views.
  #
  module QuietLeightboxHelper

    # Include Leightbox only if used for the current view, according to the
    # Controller. Invoke using "<%= include_quiet_leightbox_if_used -%>" from
    # within the HEAD section of an XHTML view. If you want your HTML output
    # to be nice and tidy in terms of indentation :-) then pass a string in
    # the optional parameter - it will be inserted before each "<script>" tag
    # in the returned HTML fragment.
    #
    # Note that a trailing newline *is* output so you can call the helper with
    # the "-%>" closing ERB tag (as shown in the previous paragraph) to avoid
    # inserting a single blank line into your output in the event that the
    # plugin is *not* used by the current view.
    #
    def include_leightbox_if_used( line_prefix = '' )
      return unless using_quiet_leightbox?

      data          = javascript_include_tag( :defaults )
      data << "\n" << javascript_include_tag( 'leightbox/leightbox' )
      data << "\n" << stylesheet_link_tag( 'leightbox/leightbox' )

      data.gsub( /^/, line_prefix ) + "\n"
    end

    # Returns 'true' if configured to use the Leightbox library for the view
    # related to the current request. See the "uses_leightbox" class method for
    # more information.
    #
    def using_quiet_leightbox?
      ! @uses_leightbox.nil?
    end
  end
end

# Install the controller and helper methods.

ActionController::Base.send( :include, QuietLeightbox )
ActionView::Base.send :include, QuietLeightbox::QuietLeightboxHelper
