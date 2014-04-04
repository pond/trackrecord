########################################################################
# File::    sign_in.rb
# (C)::     Hipposoft 2014
#
# Purpose:: Encapsulate data required for the sign-in form, mostly so
#           that we can have Rails transparently fill back in details
#           if the form needs to be displayed again due to an error.
# ----------------------------------------------------------------------
#           25-Mar-2014 (ADH): Created.
########################################################################

# This is not an ActiveRecord subclass.
#
# http://railscasts.com/episodes/219-active-model

class SignIn

  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend  ActiveModel::Naming

  attr_accessor :identity_url, :email, :password, :password_confirmation

  validates_confirmation_of :password, :unless => ->( obj ) { obj.password_confirmation.nil? }

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
