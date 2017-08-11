########################################################################
# File::    make_yaml.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Crude ICS parser that writes a YAML file encoding a Hash.
#           The Hash has Date based keys, with values giving the name of
#           the UK bank holiday on that date. No key, no holiday.
#
#           This script is run manually over a manually downloaded
#           calendar file. See comments inside the file and a "read me"
#           file inside the same folder for details.
# ----------------------------------------------------------------------
#           19-Aug-2013 (ADH): Created.
########################################################################

# You MUST run this from within the Rails environment with e.g.:
#
#   rails runner lib/report_generators/track_record_report_generator_uk_org_pond_csv_as_days/make_yaml.rb
#
# The task can be done in a more complex, but more robust way with extra
# Gem support; see for example the parsing code here:
#
#   https://github.com/jfi/bankholidays/blob/master/lib/bankholidays.rb
#
# However at the time of writing all we need is a date and a name, so
# this manually-run code currently does the job without any extra gems.

folder = File.join( 'lib',
                    'report_generators',
                    'track_record_report_generator_uk_org_pond_csv_as_days' )

calendar = File.open( File.join( folder, 'uk_bank_holidays.ics' ) ).read()
calendar.gsub!( /\r\n?/, "\n" )

parsed    = {}
last_date = nil

calendar.each_line do | line |
  if ( line[ 0..18 ].downcase == 'dtstart;value=date:' )
    last_date = Date.parse( line[ 19..-1 ].strip() )
  elsif ( line[ 0..7 ].downcase == 'summary:' )
    raise "Don't understand calendar file format" if ( last_date.nil? )
    parsed[ last_date ] = line[ 8..-1 ].strip().encode( 'UTF-8', :invalid => :replace, :undef => :replace )
  end
end

File.open( File.join( folder, 'uk_bank_holidays.yml' ), 'w' ) do | f |
  f.write( parsed.to_yaml() )
end

puts "Wrote 'uk_bank_holidays.yml' OK"
