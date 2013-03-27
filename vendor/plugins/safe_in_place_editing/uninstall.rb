########################################################################
# File::    uninstall.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Safe in-place editing. See the README for more information.
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Created.
#           29-Nov-2009 (ADH): Moved JS file down into a subdirectory
#                              to help keep the public JS folder clean.
########################################################################

require 'fileutils'

directory = File.dirname( __FILE__ )
path      = File.join( directory, '../../../public/javascripts/safe_in_place_editing' )
file      = File.join( path, '/safe_in_place_editing.js' )

FileUtils.rm( file )
FileUtils.rmdir( path )
