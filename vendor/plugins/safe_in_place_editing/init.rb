########################################################################
# File::    init.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Safe in-place editing. See the README for more information.
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Created.
########################################################################

ActionController::Base.send( :include, SafeInPlaceEditing )
ActionController::Base.helper( SafeInPlaceEditingHelper )
