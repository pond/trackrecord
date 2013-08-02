########################################################################
# File::    quiet_prototype.rb
# (C)::     Hipposoft 2009
#
# Purpose:: Only include Prototype and Scriptaculous components if a
#           view requires them.
# ----------------------------------------------------------------------
#           09-Apr-2009 (ADH): Created.
#           18-Jul-2013 (ADH): Local modifications for TrackRecord with
#                              the Rails asset pipeline.
########################################################################

module QuietPrototype
  mattr_accessor :default_options

  # Define the "uses_prototype" controller method.
  #
  module ClassMethods
    def uses_prototype( filter_options = {} )
      proc = Proc.new do | c |
        c.instance_variable_set( :@uses_prototype, true )
      end

      before_filter( proc, filter_options )
    end
  end

  # Add in the class methods and establish the helper calls when the module
  # gets included.
  #
  def self.included( base )
    base.extend( ClassMethods )
    base.helper( QuietPrototypeHelper )
  end

  # The helper module - methods for use within views.
  #
  module QuietPrototypeHelper

    # Include Prototype only if used for the current view, according to the
    # Controller. Invoke using "<%= include_quiet_prototype_if_used -%>" from
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
    def include_prototype_if_used( line_prefix = '' )
      if using_quiet_prototype?

        # 2013-07-18 (ADH): Even with appropriate configuration data in
        # "config/application.rb" for the ":defaults" expansion, using it
        # here results in "assets/defaults.js" being generated. Doh. Since
        # code here is evaluated before the application starts, presumably
        # the expansion isn't defined in time. Instead we have to do it
        # the hard way.

        data          = javascript_include_tag( 'prototype/prototype' )
        data << "\n" << javascript_include_tag( 'prototype_ujs/rails' )
        data << "\n" << javascript_include_tag( 'scriptaculous/scriptaculous' )

        return ( data.gsub( /^/, line_prefix ) + "\n" ).html_safe()
      end
    end

    # Returns 'true' if configured to use the Prototype library for the view
    # related to the current request. See the "uses_prototype" class method for
    # more information.
    #
    def using_quiet_prototype?
      ! @uses_prototype.nil?
    end
  end
end

# Install the controller and helper methods.

ActionController::Base.send( :include, QuietPrototype )
ActionView::Base.send :include, QuietPrototype::QuietPrototypeHelper
