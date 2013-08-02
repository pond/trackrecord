########################################################################
# File::    timesheet_force_commit.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Encapsulate data required for a bulk timesheet commit
#           session.
# ----------------------------------------------------------------------
#           01-Aug-2013 (ADH): Created.
########################################################################

# This is not an ActiveRecord subclass.
#
# http://railscasts.com/episodes/219-active-model

class TimesheetForceCommit

  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend  ActiveModel::Naming

  attr_reader   :earliest_limit, :latest_limit
  attr_accessor :earliest,       :latest

  # ====================================================================
  # Custom accessors
  # ====================================================================

  # We use a private coerce-to-date function rather than Rails' built
  # in "to_date" because of the latter's bizarre behaviour when faced
  # with invalid strings (user-meaningless exceptions arising from the
  # internal implementation, rather than Ruby's "invalid date").
  #
  # The values used for limits end up always coerced to dates, while
  # the user-specified "earliest" and "latest" are left to whatever the
  # user set. That way, re-rendering a form complaining about e.g. an
  # invalid date will make sense by presenting the user-set data, not
  # parsed or cleared-out variation of it.

  def earliest_limit=( value )
    @earliest_limit = to_date( value )
  end

  def latest_limit=( value )
    @latest_limit = to_date( value )
  end

  # ====================================================================
  # Utility methods
  # ====================================================================

  # Neither NilClass (annoyingly) or Date (sensibly) provide "empty?"
  # but we want to detect both empty strings, or true nil, while still
  # allowing Date instances. So pass a value and get true/false if it
  # is, or is not, effectively empty.
  #
  def effectively_empty( value )
    value.nil? || value.to_s.empty?
  end

  # Pass a Date, DateTime, Time, string etc. and have it parsed to a
  # Date. Returns the result (or throws an exception). If the value
  # given is effectively empty (e.g. nil, empty string) then the
  # method returns 'nil'.
  #
  def to_date( value )
    effectively_empty( value ) ? nil : Date.parse( value.to_s )
  end

  # ====================================================================
  # Boilerplate code for Rails
  # ====================================================================

  def initialize( attributes = {} )
    attributes ||= {}
    attributes.each do | name, value |
      send( "#{name}=", value )
    end
  end
  
  def persisted?
    false
  end
end
