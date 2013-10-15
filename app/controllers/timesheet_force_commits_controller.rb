########################################################################
# File::    timesheet_force_commits_controller.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Allow administrators to bulk-commit timesheets forcibly, to
#           help deal with users who never manually commit them.
# ----------------------------------------------------------------------
#           31-Jul-2013 (ADH): Created.
########################################################################

class TimesheetForceCommitsController < ApplicationController

  uses_prototype()

  # Security and prerequisites

  before_filter( :permitted? )
  before_filter( :assign     )

  def new
    unless ( @timesheets.count.zero? )
      @object.earliest = @object.earliest_limit
      @object.latest   = @object.latest_limit
    end
  end

  def create

    # Unless we get here by someone hacking around with a web page,
    # the only explanation for a submitted form but a re-counted
    # timesheet count of zero would be that users submitted things
    # in other browser sessions while the admin was thinking about
    # filling in the submitted form.

    if ( @timesheets.count.zero? )
      flash[ :error ] = "No action taken - while you were using the form, all timesheets were committed by their users anyway."
      redirect_to( home_path() ) and return
    end

    # Get a valid, parsed set of Dates into @earliest/@latest
    # - or nil.

    form_data = params[ :timesheet_force_commit ]

    # The "to_date" call may cause date parsing exceptions.

    begin
      @object.earliest = @object.to_date( form_data[ :earliest ] )
      @object.latest   = @object.to_date( form_data[ :latest   ] )

    rescue => error
      complain( error ) and return

    end

    # Pick earliest/latest instead of 'nil' and bounds check dates.

    @object.earliest = @object.earliest_limit if ( @object.earliest.nil? || @object.earliest < @object.earliest_limit )
    @object.latest   = @object.latest_limit   if ( @object.latest.nil?   || @object.latest   > @object.latest_limit   )

    # Update timesheets.

    begin

      Timesheet.transaction do

        # Construct an ActiveRecord::Relation instance with the
        # appropriate constraints, then iterate over it in batches
        # using "find_each".
        #
        # Remember that "@object.latest" is an inclusive timesheet
        # end date and everything runs in UTC.
        #
        # We can't use "update_all", even though it'd be fast, as
        # it doesn't trigger callbacks or validations and both are
        # important (particularly callbacks).

        timesheets = Timesheet.where( :committed => false )
        timesheets = timesheets.where( 'start_day_cache >= ?', @object.earliest )
        timesheets = timesheets.where( 'start_day_cache <= ?', @object.latest - 6.days )

        timesheets.find_each do | timesheet |
          timesheet.committed = true
          timesheet.save!
        end
      end

    rescue => error
      complain( error ) and return

    end

    flash[ :notice ] = "Timesheets committed successfully."
    redirect_to( home_path() )
  end

private

  # Is the current action permitted?
  #
  def permitted?
    appctrl_not_permitted() unless ( @current_user.privileged? )
  end
  
  # Assign useful instance variables.
  #
  def assign 

    # Start by getting all uncommitted timesheets.

    @timesheets = Timesheet.where( :committed => false ).order( 'start_day_cache ASC' )

    # Further restrict this to timesheets ending before the start of
    # the current month. If the current week falls into the previous
    # month - i.e. the current week starts sooner than the month -
    # then go back one month from there. The idea is to be able to
    # "close off" a historical month, without accidentally commiting
    # timesheets in "this" month (or close to it) that a user may be
    # legitimately editing.
    #
    # Under Rails, subtracting "1.month" from a Date does do the right
    # thing - it doesn't just subtract a fixed number of days. Whatever
    # month it is now, we end up with the start of the previous month.

    earliest = Date.today.beginning_of_month
    compare  = Date.today.beginning_of_week

    @earliest = ( compare < earliest ) ? earliest - 1.month : earliest

    # Remember, we want the timesheet's *last day* to fall *before*
    # the start-of-month date now stored in "earliest". Or to put it
    # another way, any timesheet that starts at or earlier than 7
    # days prior to "earliest" must finish just before "earliest".

    @timesheets = @timesheets.where( 'start_day_cache <= ?', @earliest - 7.days )

    unless ( @timesheets.count.zero? )
      @object                = TimesheetForceCommit.new()
      @object.earliest_limit = @timesheets.first.start_day_cache
      @object.latest_limit   = @timesheets.last.start_day_cache + 6.days
    end
  end

  # Complain about the given exception, showing the 'new' form again.
  #
  def complain( error )

    # Restore raw, user-set data so the user sees exactly what they
    # typed into form fields, rather than a parsed version.

    form_data = params[ :timesheet_force_commit ]

    @object.earliest = form_data[ :earliest ]
    @object.latest   = form_data[ :latest   ]

    flash[ :error ] = "Could not commit timesheets: #{ error }"
    render( { :action => :new } )
  end
end
