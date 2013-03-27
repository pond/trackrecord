########################################################################
# File::    install.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Safe in-place editing. See the README for more information.
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Created.
#           29-Nov-2009 (ADH): Moved JS file down into a subdirectory
#                              to help keep the public JS folder clean.
########################################################################

require 'erb'
require 'find'
require 'fileutils'

@warnings = false
puts

# Copy the local JS data into 'public'.

src_root = File.dirname( __FILE__ ) + '/lib/safe_in_place_editing/resources/'
dst_root = File.dirname( __FILE__ ) + '/../../../public/'
js_dir   = dst_root + 'javascripts/safe_in_place_editing'

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
puts "documentation with 'rake doc:plugins:safe_in_place_editing'."
puts
