########################################################################
# File::    add_submodules_method_to_module.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Add a "submodules" method to Module, analogous to the
#           "subclasses" method of Class that Rails provides. From:
#
#             http://www.natontesting.com/2010/06/30/how-to-get-the-submodules-of-a-ruby-module/
#
# ----------------------------------------------------------------------
#           30-Jul-2013 (ADH): Created.
########################################################################

class Module
  def submodules
    constants.collect { | const_name | const_get( const_name ) }.select { | const | const.class == Module }
  end
end
