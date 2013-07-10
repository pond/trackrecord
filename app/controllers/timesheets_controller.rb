########################################################################
# File::    timesheets_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage Timesheet objects. See models/timesheet.rb for more.
# ----------------------------------------------------------------------
#           07-Jan-2008 (ADH): Created.
########################################################################

class TimesheetsController < ApplicationController

  # YUI tree component for task selection

  dynamic_actions = { :only => [ :edit, :update ] }

  uses_prototype( :only => :index )
  uses_leightbox( dynamic_actions )
  uses_yui_tree(
    { :xhr_url_method => :trees_path },
    dynamic_actions
  )

  # List timesheets.

  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text  => 'Start day',   :value_method => 'start_day',                 :sort_by => 'start_day_cache'             },
      { :header_text  => 'Owner',       :value_helper => :timesheethelp_owner,        :sort_by => 'users.name, start_day_cache' },
      { :header_text  => 'Last edited', :value_helper => :timesheethelp_updated_at,   :sort_by => 'updated_at'                  },
      { :header_text  => 'Committed',   :value_helper => :timesheethelp_committed_at, :sort_by => 'committed_at'                },
      { :header_text  => 'Hours',       :value_helper => :timesheethelp_hours,
        :header_align => 'center',      :value_align  => 'center'                                                               },
    ]

    # Get the basic options hash from ApplicationController, then work out
    # the conditions on objects being fetched, including handling the search
    # form data.

    options              = appctrl_index_assist( Timesheet )
    committed_vars       = { :committed => true,  :user_id => @current_user.id }
    not_committed_vars   = { :committed => false, :user_id => @current_user.id }
    user_conditions_sql  = "WHERE ( timesheets.committed = :committed ) AND ( users.id  = :user_id )\n"
    other_conditions_sql = "WHERE ( timesheets.committed = :committed ) AND ( users.id != :user_id )\n"

    range_sql, range_start, range_end = appctrl_search_range_sql( Timesheet, :start_day_cache )

    # If asked to search for something, build extra conditions to do so.

    unless ( range_sql.nil? )
      search_num = params[ :search ].to_i
      search_str = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string

      conditions_sql = "AND #{ range_sql } ( timesheets.year = :search_num OR timesheets.week_number = :search_num OR users.name ILIKE :search_str )"
      vars           = { :search_num => search_num, :search_str => search_str, :range_start => range_start, :range_end => range_end }

      user_conditions_sql  << conditions_sql
      other_conditions_sql << conditions_sql

      committed_vars.merge!( vars )
      not_committed_vars.merge!( vars )
    end

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }"
    options.delete( :order )

    basic_sql = "SELECT timesheets.* FROM timesheets\n" <<
                "INNER JOIN users ON ( timesheets.user_id = users.id )"

    user_finder_sql  = "#{ basic_sql }\n#{ user_conditions_sql  }\n#{ order_sql }"
    other_finder_sql = "#{ basic_sql }\n#{ other_conditions_sql }\n#{ order_sql }"

    # Now paginate using this SQL query.

    @user_committed_timesheets      = Timesheet.paginate_by_sql( [ user_finder_sql,  committed_vars     ], options )
    @user_not_committed_timesheets  = Timesheet.paginate_by_sql( [ user_finder_sql,  not_committed_vars ], options )
    @other_committed_timesheets     = Timesheet.paginate_by_sql( [ other_finder_sql, committed_vars     ], options )
    @other_not_committed_timesheets = Timesheet.paginate_by_sql( [ other_finder_sql, not_committed_vars ], options )
  end

  # Prepare for the 'new timesheet' view.

  def new
    @years = Timesheet.allowed_range()

    @year  = params[ :menu ][ :year ].to_i if ( params[ :menu ] )
    @year  = @year || ( Time.new ).year

    @year -= 1 unless( params[ :previous ].nil? )
    @year += 1 unless( params[ :next     ].nil? )

    @year  = @years.first if ( @year < @years.first )
    @year  = @years.last  if ( @year > @years.last  )
  end

  # Create a blank timesheet based on the year and week_number values in
  # the params hash. Save and redirect to edit the timesheet immediately.
  # Certain defaults are set up here - the model would be a better place,
  # but it does not have access to the right instance variables or methods
  # required to determine the appropriate values.

  def create
    @timesheet             = Timesheet.new()
    @timesheet.year        = params[ :year ]
    @timesheet.week_number = params[ :week_number ]
    @timesheet.user        = @current_user
    @timesheet.committed   = false

    # Protect against people hacking around with forms submissions and
    # attempting to create new timesheets for already-claimed weeks

    clash = Timesheet.find_by_user_id_and_year_and_week_number(
      @current_user.id,
      @timesheet.year,
      @timesheet.week_number
    )

    if ( clash )
      flash[ :error ] = "A timesheet for week #{ @timesheet.week_number } has already been created."
    elsif ( @timesheet.save )
      flash[ :notice ] = 'New timesheet created and ready for editing.'
      redirect_to( edit_timesheet_path( @timesheet ) )
      return
    end

    render( :action => 'new' )
  end

  # Prepare to edit a timesheet. Any defaults are established
  # by the models automatically. Rows and work packets are
  # included in the editing form.

  def edit
    @timesheet = Timesheet.find( params[ :id ] )
    return appctrl_not_permitted() unless @timesheet.can_be_modified_by?( @current_user )

    set_next_prev_week_variables( @timesheet )
    @selected_rows = []
  end

  # Update a timesheet, its rows and work packets.

  def update

    @timesheet = Timesheet.find( params[ :id ] )
    return appctrl_not_permitted() unless @timesheet.can_be_modified_by?( @current_user )

    @errors = update_backend( @timesheet )

    if ( @errors.nil? )
      flash[ :error ] = 'This timesheet was modified by someone else while you were making changes. Please examine the updated information before editing again.'
      redirect_to( timesheet_path( @timesheet ) )
      return
    end

    @timesheet.reload()

    if ( @errors.empty? )
      flash[ :notice ] = "Week #{ @timesheet.week_number } changes saved."
    else
      render( :action => :edit )
      return
    end

    set_next_prev_week_variables( @timesheet )

    # Save and edit next or previous editable week, creating a clone
    # timesheet for a previously unused week if need be?

    if ( params[ :next ] or params[ :previous ] )
      another = params[ :next ] ? @next_week : @prev_week

      if ( another.nil? )
        flash[ :error ] = "Cannot find another week to edit in #{ @timesheet.year }."
        redirect_to( new_timesheet_path() )
        return
      end

      new_week      = another[ :week_number ]
      new_timesheet = another[ :timesheet   ]

      if ( new_timesheet.nil? )
        new_timesheet           = clone_timesheet( @timesheet, new_week )
        new_timesheet.committed = false

        if ( new_timesheet.nil? )
          flash[ :error ] = "Unable to create a new timesheet for week #{ new_week }."
        else
          flash[ :notice ] << " Now editing a new timesheet for week #{ new_week }."
        end
      else
        flash[ :notice ] << " Now editing the timesheet for week #{ new_week }."
      end

      if ( new_timesheet.nil? )
        redirect_to( new_timesheet_path() )
      else
        redirect_to( edit_timesheet_path( new_timesheet ) )
      end

    elsif ( @timesheet.committed || params[ :commit ] == 'Save changes and exit' )
      redirect_to( new_timesheet_path() )

    else
      render( :action => :edit )

    end
  end

  # Show timesheet details.

  def show
    @timesheet = Timesheet.find( params[ :id ] )
    return appctrl_not_permitted() unless ( @timesheet and ( @current_user.privileged? or @timesheet.user_id == @current_user.id ) )

    set_next_prev_week_variables_for_show( @timesheet )
  end

  # Timesheets should not normally be destroyed. Only administrators
  # can do this.

  def delete
    appctrl_delete( 'Timesheet' )
  end

  def destroy
    appctrl_admin_destroy( Timesheet )
  end

private

  # Set @next_week and @prev_week to the data describing the next and
  # previous editable week after the given timesheet, or nil for no such
  # week. This involves searching week by week for an empty week or a
  # not committed timesheet, so may be slow.
  #
  # For details of the data stored in the variables, see the Timesheet
  # model's 'editable_week' method.

  def set_next_prev_week_variables( timesheet )
    @next_week = timesheet.editable_week( true  )
    @prev_week = timesheet.editable_week( false )
  end

  # As set_next_prev_week_variables, but sets variables for a 'show' view.
  # See the Timesheet model's 'showable_week' method for details.

  def set_next_prev_week_variables_for_show( timesheet )
    @next_week = timesheet.showable_week( true  )
    @prev_week = timesheet.showable_week( false )
  end

  # Back-end method that takes the complex form submission of an
  # 'edit' form and unpicks it to update a timesheet's work packets,
  # rows and the timesheet itself. Returns an array of error messages,
  # or an empty array if the operation was successful. Returns nil if
  # the timesheet has been edited concurrently by someone else - the
  # caller should generate an appropriate message and, usually, redirect
  # to the 'show' view.
  #
  # Pass in the timesheet object for which the overall operation is
  # being carried out. Assumes that 'params' contains all other data.

  def update_backend( timesheet )
    errors = []

    # I can't get automatic optimistic locking around the timesheet to work
    # properly at all, so do it by hand!

    return nil if ( params[ :timesheet ][ :lock_version ].to_i != timesheet.lock_version )

    # "operate_on_row_*" entries indicate check boxes were ticked. Extract
    # IDs from the keys for use later.

    operate_on_rows = []

    params.keys.each do | key |
      if ( key[ 0..14 ] == 'operate_on_row_' )
        operate_on_rows.push( key[ 15..-1 ].to_i )
      end
    end

    # Store the list so that if the view is rendered again, the same selection
    # can be maintained. See the timesheet row edit partial for usage.

    @selected_rows = operate_on_rows

    Timesheet.transaction do

      # Do row removal and so-on within a transaction so if anything goes
      # wrong here or anywhere else during the update, the whole lot is
      # rolled back.

      if ( params[ :remove_row ] )
        operate_on_rows.each do | row_id |

          # Note that this fails:
          #
          #   timesheet.timesheet_rows.destroy( row_id )
          #
          # Someone, somewhere aggregates SQL queries and you end up with
          # an invalid SQL fragment, e.g.:
          #
          #  UPDATE timesheet_rows SET position = (position - 1)
          #  WHERE (timesheet_rows.timesheet_id = 3) AND
          #        (timesheet_id = 3 AND position > 1)
          #  ORDER BY position
          #  ^^^^^^^^^^^^^^^^^ <-- That's acts_as_list interfering.
          #
          # We need to find the row explicitly, then destroy it. Upon being
          # destroyed, the SQL is more sane, e.g.:
          #
          #  UPDATE timesheet_rows SET position = (position - 1)
          #   WHERE (timesheet_id = 3 AND position > 1)
          #
          # Thanks to ferric on #rubyonrails for assistance with tracking
          # down the fault.

          timesheet.timesheet_rows.find( row_id ).destroy
        end
      end

      # Deal with main timesheet updates before sorting, so that auto-sort
      # can apply after row additions, removals and any other updates.

      timesheet_hash = params[ :timesheet ]

      if ( not timesheet_hash[ :timesheet_row_ids ].nil? )
        timesheet_hash[ :timesheet_row_ids ].keys.each do | row_id |

          # If the user deleted a row then some of the forms entries
          # are not valid - catch the error early.

          next if not timesheet.timesheet_row_ids.include?( row_id.to_i )

          row_hash = timesheet_hash[ :timesheet_row_ids ][ row_id ]
          row_hash[ :work_packet_ids ].keys.each do | packet_id |
            packet_hash = row_hash[ :work_packet_ids ][ packet_id ]
            @work_packet = WorkPacket.find( packet_id )

            packet_hash[ :worked_hours ].strip
            packet_hash[ :worked_hours ] = '0' if ( packet_hash[ :worked_hours ].empty? )

            # If a work packet is invalid, keep trying all the others.
            # We don't want a typo in one 'cell' of the timesheet to
            # cause all subsequent 'cells' to be ignored.

            begin
              @work_packet.update_attributes!( packet_hash )

            rescue => error
              timesheet_row = TimesheetRow.find( row_id )
              task          = timesheet_row.task if not timesheet_row.nil?
              task_title    = task.nil? ? 'Unknown' : task.augmented_title;

              packet_hash[ :worked_hours ] = ''

              errors.push( "Task '#{ task_title }', " <<
                           "#{ Date::DAYNAMES[ @work_packet.day_number ] }: " <<
                           "#{ error.message } - the field value has been reset" )
            end
          end

          # Presently, there's nothing in rows to update - really, a
          # row is just a join table. So no need for this:
          #
          # ...manually update specific attributes, then...
          # timesheet_row = TimesheetRow.find( row_id )
          # timesheet_row.save!
        end
      end

      # If moving rows around, be careful; when moving rows up, move
      # the lowest numbered position first (else others are renumbered
      # when one moves and things go pear shaped); vice versa for moving
      # rows down.
      #
      # Manually moving rows defeats auto-sort. Obviously you can't have
      # some rows manually moved around, then just sort them!

      if ( ( params[ :move_row_down ] or params[ :move_row_up ] ) and not operate_on_rows.empty? )

        timesheet.auto_sort = nil
        timesheet_hash.delete( :auto_sort )

        down        = params[ :move_row_down ]
        row_objects = TimesheetRow.find( operate_on_rows, :order => :position )
        row_objects.reverse! if ( down )

        row_objects.each do | row |
          down ? row.move_lower() : row.move_higher()
          row.save!()
        end
      end

      # Deal with adding rows, if required.

      unless ( params[ :add_row ].nil? )
        appctrl_patch_params_from_js( :timesheet )
        ids = params[ :timesheet ][ :task_ids ]

        if ( ids.blank? )
          errors.push( "No tasks selected - first choose one or more tasks from the list, then use the 'Add' button" )
        else
          ids.each do | id |
            begin
              task = Task.find_by_id( id )
              timesheet.add_row( task )
            rescue => error
              errors.push( "Adding task '#{ task.title }': #{ error.message }" )
            end
          end
        end
      end

      # Now worry about manual one-off or automatic sorting.

      if ( params[ :sort_once ] )

        # Clear auto-sort and retrieve what we treat as a one-off
        # sort parameter from the timesheet auto-sort form data.

        timesheet.auto_sort = nil
        sorting             = timesheet_hash[ :auto_sort ]

      else

        # Change or maintain auto-sort and use this for sorting.

        timesheet.auto_sort = timesheet_hash[ :auto_sort ] || timesheet.auto_sort
        sorting             = timesheet.auto_sort

      end

      if ( sorting )
        row_objects = timesheet.timesheet_rows.all.dup

        case sorting
          when 'rows_added'
            row_objects.sort! { | a, b | a.id <=> b.id }
          when 'tasks_added'
            row_objects.sort! { | a, b | a.task.id <=> b.task.id }
          when 'task_title'
            row_objects.sort! { | a, b | a.task.title <=> b.task.title }
          when 'task_code'
            row_objects.sort! { | a, b | a.task.code <=> b.task.code }
          when 'associations'
            row_objects.sort! { | a, b | a.task.augmented_title <=> b.task.augmented_title }
        end

        row_objects.each_with_index do | row, index |
          row.set_list_position( index + 1 )
          row.save!
        end
      end

      # Other simple parameters.

      timesheet.week_number = timesheet_hash[ :week_number ]
      timesheet.description = timesheet_hash[ :description ]
      timesheet.committed   = timesheet_hash[ :committed   ]

      begin
        timesheet.save!
      rescue => error
        errors.push( "Timesheet: #{ error.message }" )
      end

      # If there were any errors handled internally that did not go via
      # an exception, the transaction won't roll back. Force it to do so.

      raise( "Rollback" ) unless( errors.empty? )
    end

    return errors

  rescue => error # Don't use 'ensure', because early exits elsewhere may fail then.
    errors.push( "Timesheet: #{ error.message }" )
    return errors

  end

  # Clone a timesheet - well, sort of. Creates a clone of the given timesheet
  # in terms of the rows it contains, but not the work packets. Assigns the
  # same user and year, but the given week; that week must be available. Saves
  # the result. Returns the timesheet if saved successfully, else nil.

  def clone_timesheet( original, week_number )
    timesheet             = Timesheet.new
    timesheet.user_id     = original.user_id
    timesheet.auto_sort   = original.auto_sort
    timesheet.year        = original.year
    timesheet.week_number = week_number

    Timesheet.transaction do

      # Save to get an ID that allows the row/task associations to work.

      timesheet.save!

      # Now remove the default assigned rows. We remove them all, even if
      # they may be re-added when we copy rows from the original timesheet,
      # because the ordering may have to change too. This code isn't fast
      # but it's clear, simple and reliable.

      timesheet.timesheet_rows.find_each do | row |
        timesheet.timesheet_rows.destroy( row.id )
      end

      # Now add rows equivalent to those in the original timesheet.

      original.timesheet_rows.find_each do | row |
        new_row = timesheet.add_row( row.task )
        new_row.set_list_position( row.position ) unless new_row.nil?
      end

      # Save again, to be sure that the row changes are persisted.

      timesheet.save!

    end

    return timesheet

  rescue
    return nil

  end

end
