########################################################################
# File::    install.rb
# (C)::     Hipposoft 2009
#
# Purpose:: Install the plugin.
# ----------------------------------------------------------------------
#           09-Dec-2009 (ADH): Comment header added ready for first
#                              public release of the plugin.
########################################################################

# Copy the configuration YAML file template into place.

require 'erb'
require 'find'
require 'fileutils'

config    = File.dirname( __FILE__ ) + '/../../../config/yui_tree.yml'
@warnings = false
puts

unless File.exist?( config )
  config_template = IO.read( File.dirname( __FILE__ ) + '/yui_tree.yml.tpl' )
  File.open( config, 'w' ) { | f | f << ERB.new( config_template ).result }
else
  @warnings = true

  puts "Configuration file 'config/yui_tree.yml' already exists; not"
  puts "overwriting it. If updating to a newer version of this plugin, you"
  puts "may want to rename the old configuration file and install again to"
  puts "get the latest version of the default settings. Then merge in any"
  puts "customisations you made to the old configuration file."
  puts
end

# Copy the local JS data into 'public'.

src_root = File.dirname( __FILE__ ) + '/lib/yui_tree/resources/'
dst_root = File.dirname( __FILE__ ) + '/../../../public/'
js_dir   = dst_root + 'javascripts/yui_tree'

def careful_mkdir( path )
  if File.exist?( path )
    raise "A file already exists at '#{ File.expand_path( path ) }'" unless File.directory?( path )
  else
    FileUtils.mkdir( path )
  end
end

careful_mkdir( js_dir )

def careful_copy_all( src_root, src_add, dst_dir, extension )
  src_dir = src_root + src_add

  Find.find( src_dir ) do | src_path |
    next unless ( File.extname( src_path ) == extension )
    dst_path = dst_dir + '/' + File.basename( src_path )

    if ( File.exist?( dst_path ) )
      puts "Skipping copy action - will not overwrite existing file:"
      puts "  #{ File.expand_path( dst_path ) }"
      puts "If you have installed on top of a previous installation, you may"
      puts "want to delete the existing file and try again, assuming it is"
      puts "from an older plugin version and has no local modifications."
      puts
      @warnings = true
    else
      puts "Copying #{ src_add }/#{ File.basename( src_path ) }..."
      FileUtils.cp( src_path, dst_path )
    end
  end
end

careful_copy_all( src_root, 'javascripts', js_dir, '.js'  )

# All done; summarise the results.

if ( @warnings )
  puts "Finished with warnings - please take note of the details above and"
  puts "take appropriate actions to finish installing the plugin."
else
  puts "Successful."
end

puts
puts "For further information, check out the README file and/or generate HTML"
puts "documentation with 'rake doc:plugins:yui_tree'."
puts
