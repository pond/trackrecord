# http://stackoverflow.com/questions/490507/best-way-to-export-a-database-table-to-a-yaml-file

namespace :db do
  task :extract_fixtures => :environment do
    sql         = 'SELECT * FROM "%s"'
    skip_tables = [ "schema_migrations" ]

    ActiveRecord::Base.establish_connection

    if ( not ENV[ 'TABLES' ] )
      tables = ActiveRecord::Base.connection.tables - skip_tables
    else
      tables = ENV[ 'TABLES' ].split( /, */ )
    end

    # Delete join and sundry tables used by TrackRecord that are not appropriate
    # for fixtures, or can't be dumped as fixtures with the code below.

    tables -= [
      "open_id_authentication_associations",
      "open_id_authentication_nonces"
    ]

    if ( not ENV[ 'OUTPUT_DIR' ] )
      output_dir = "#{ Rails.root }/test/fixtures"
    else
      output_dir = ENV[ 'OUTPUT_DIR' ].sub( /\/$/, '' )
    end

    ( tables ).each do | table_name |
      i = "000"

      File.open( "#{ output_dir }/#{ table_name }.yml", 'w' ) do | file |

        data = ActiveRecord::Base.connection.select_all( sql % table_name )

        # Unfortunately select_all returns everything as strings, with times
        # at at precision that strips any trailing zeroes, e.g.:
        #
        #   2013-10-09 06:22:46.552
        #
        # The maximum precision (by observation) is 6dp, e.g.:
        #
        #   2013-10-09 06:22:46.544667
        #
        # This is a problem for at least SQLite3, maybe others. SQLite 3 has
        # been observed to be *very* broken regarding times not specified to
        # the full 6dp under Rails and the Rails adapter - its concept of
        # whether a time ".552" vs ".552000" are equivalent, earlier or later
        # is very bizarre and *not* the expected "they're the same".
        #
        # Thus if we do nothing here, all tests would fail under such engines.
        # Time and date edge comparisons would not work as expected. So we
        # have to ask ActiveRecord to also get a properly instantiated item,
        # find all date/time style columns in there and rewrite every field
        # in the data-for-YAML so that it has a full six decimal places in it.
        #
        # Ugh.
        #
        # Note for-speed assumptions on string-based date/time formats, as
        # given above. A 'correct' item is 26 characters long. If 19 long, it
        # has no decimal point at all, so that's added. The result is padded
        # to 26 characters using "0"s.

        if ( data.count > 0 )
          begin
            example = table_name.classify.constantize.first
          rescue
            # Table has no direct AR representation, probably a join table
            # for HABTM relationships
            example = {}
          end

          date_columns = []
          data.first.keys.each do | key |
            date_columns << key if example[ key ].class == ActiveSupport::TimeWithZone 
          end

          if ( date_columns.length > 0 )
            data.each do | data_item |
              date_columns.each do | date_column |
                value = data_item[ date_column ]
                next if value.nil?
                value << "." if ( value.length == 19 ) # E.g. "2013-10-09 06:22:46"
                data_item[ date_column ] = value.ljust( 26, "0" ) # E.g. "2013-10-09 06:22:46.000000"
              end
            end
          end
        end

        file.write data.inject( {} ) { | hash, record |
          hash[ "#{ table_name }_#{ i.succ! }" ] = record
          hash
        }.to_yaml

        puts "Wrote #{ table_name } to #{ output_dir }"
      end
    end
  end
end
