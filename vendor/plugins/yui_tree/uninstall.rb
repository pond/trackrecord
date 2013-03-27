########################################################################
# File::    install.rb
# (C)::     Hipposoft 2009
#
# Purpose:: Remove the plugin.
# ----------------------------------------------------------------------
#           09-Dec-2009 (ADH): Comment header added ready for first
#                              public release of the plugin.
########################################################################

require 'find'
require 'pathname'

puts
puts "The following files are installed with the plugin but not manually"
puts "removed in case you have edited them and want to preserve changes:"
puts

yml_root = File.expand_path( File.dirname( __FILE__ ) + '/../../../config/yui_tree.yml' )
yml_path = Pathname.new( yml_root )
pwd_path = Pathname.new( Dir.pwd )

puts '  ./' + yml_path.relative_path_from( pwd_path )

js_root  = File.expand_path( File.dirname( __FILE__ ) + '/../../../public/javascripts/yui_tree' )
js_path  = Pathname.new( js_root )
pwd_path = Pathname.new( Dir.pwd )

puts '  ./' + js_path.relative_path_from( pwd_path ) + "/<all files>"
puts
