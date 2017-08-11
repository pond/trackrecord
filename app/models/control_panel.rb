########################################################################
# File::    control_panel.rb
# (C)::     Hipposoft 2007
#
# Purpose:: Manage settings for individual User models. See below for
#           more details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class ControlPanel < ActiveRecord::Base

  # A ControlPanel object manages settings for a User. Among
  # other things, it allows a HABTM relationship with Tasks for
  # the default tasks shown in a Timesheet, while a User object
  # also maintains a HABTM relationship with Tasks for a list
  # of the tasks that the user is allowed to see.

  belongs_to( :user )
  has_and_belongs_to_many( :tasks )

  serialize :preferences

  # Default customer and project to associate with a new task.

  belongs_to( :project  )
  belongs_to( :customer )

  # Remove inactive tasks from the control panel. The caller
  # is responsible for saving the updated object.
  #
  def remove_inactive_tasks
    # See the User model's remove_inactive_tasks method for details.

    self.tasks = self.tasks.where( :active => true )
  end

  # Get a value from the instance's preferences hash. The hash is nested in a
  # similar manner to the I18n module's translation hashes and is addressed
  # in a similar way - pass a dot-separated key string, e.g. "foo.bar.baz".
  # Returns 'nil' for unset preferences, else the value at that location.
  #
  # Currently defined preferences include (but may not be limited to - this
  # list may be out of date) the following:
  #
  #   sorting => { <controller-name> => { <sort data> } }
  #
  #     Most recently recorded value of params[:sort] by an index action for
  #     a controller identified by <controller_name>. For more information see
  #     "appctrl_apply_sorting_preferences".
  #
  #   per_page => { <controller-name> => { <pagination data> } }
  #
  def get_preference( key_str )
    keys = key_str.split( '.' )
    pref = self.preferences

    for key in keys
      return nil if pref.nil?
      pref = pref[ key ]
    end

    return pref
  end

  # Set the value of a preference identified as for "get_preference" above.
  # If any of the nested hashes identified by the key string are missing (e.g.
  # in example "foo.bar.baz", any of hashes "foo", "bar" or "baz") then
  # relevant entries in the preferences will be made automatically.
  #
  # The method saves 'self' back to database and returns the return value of
  # the call made to "save". Thus returns 'false' on failure, else 'true'.
  #
  # See also "set_preference!".
  #
  def set_preference( key_str, value )
    return set_preference_by_method!( key_str, value, :save )
  end

  # As "set_preference" but returns the result of a call to "save!", so raises
  # an exception on failure.
  #
  def set_preference!( key_str, value )
    return set_preference_by_method!( key_str, value, :save! )
  end

  # ===========================================================================
  # PRIVATE
  # ===========================================================================

private

  # Implement "set_preference" and "set_preference!" - pass the preference
  # key string, preference value and ":send" or ":send!" depending on the
  # method required for saving the preference changes.
  #
  def set_preference_by_method!( key_str, value, method )
    keys = key_str.split( '.' )
    root = self.preferences || {}
    pref = root

    keys.each_index do | index |
      key = keys[ index ]

      if ( index == keys.size - 1 )
        pref[ key ] = value
      else
        pref[ key ] ||= {}
        pref = pref[ key ]
      end
    end

    self.preferences = root
    return self.send( method )
  end
end
