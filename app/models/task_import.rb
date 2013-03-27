########################################################################
# File::    task_import.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Encapsulate data required for a task import session.
# ----------------------------------------------------------------------
#           16-May-2008 (ADH): Created.
#           28-Nov-2009 (ADH): Made more model-like with lots of extra
#                              processing code to rationalise unusual
#                              data types used in property assignments.
########################################################################

class TaskImport

  require 'ostruct'
  require 'rexml/document'

  attr_reader( :project_id, :collapse )
  attr_reader( :tasks, :parent_uids, :parent_titles, :project_id, :collapse )
  attr_reader( :filtered_tasks, :filtered_parent_uids, :filtered_parent_titles )

  # Create a new Import object, optionally from form submission parameters.
  #
  def initialize( params = nil )
    @project_id             = nil

    @tasks                  = []
    @parent_uids            = nil
    @parent_titles          = nil

    @filtered_tasks         = []
    @filtered_parent_uids   = nil
    @filtered_parent_titles = nil
    @collapse               = nil

    @max_level              = nil

    unless ( params.nil? )

      # Adapted from ActiveRecord::Base "attributes=", Rails 2.1.0
      # on 29-Jun-2008.

      attributes = params.dup
      attributes.stringify_keys!
      attributes.each do | key, value |
        if ( key.include?( '(' ) )
          raise( "Multi-parameter attributes are not supported." )
        else
          send( key + "=", value )
        end
      end
    end
  end

  # Coerce strings to integers for certain properties.
  #
  def project_id=( val )
    @project_id = val.to_i
  end
  def collapse=( val )
    @collapse = val.to_i
  end

  # Due to the way the forms are constructed, arrays will usually be encoded
  # as a HashWithIndifferentAccess set up with keys containing a string
  # version of the index at which we should store the entry and the second
  # element with the hash describing the object to store there.
  #
  def tasks=( tasks )
    @max_level = nil
    @tasks     = to_task_array( tasks )
  end
  def parent_uids=( uids )
    @parent_uids = to_nested_array( uids )
  end
  def parent_titles=( titles )
    @parent_titles = to_nested_array( titles )
  end
  def filtered_tasks=( tasks )
    @filtered_tasks = to_task_array( tasks )
  end
  def filtered_parent_uids=( uids )
    @filtered_parent_uids = to_nested_array( uids )
  end
  def filtered_parent_titles=( titles )
    @filtered_parent_titles = to_nested_array( titles )
  end

  # Read the maximum level stored in the 'tasks' array. Generated on the fly
  # and cached until 'tasks' gets reset.
  #
  def max_level
    if ( @max_level.nil? )
      @max_level = @tasks.collect { | t | t.level }.max
    end

    return @max_level
  end

  # Take this object's (fully set up) task array along with the associated
  # parent title and UID arrays; then collapse these using this object's
  # 'collapse' value and update the internal filtered task, parent title and
  # parent UID arrays ("filtered_tasks", "filtered_parent_uids" and
  # "filtered_parent_titles").
  #
  def generate_filtered_task_list
    collapse_level         = self.collapse.to_i
    collapsed_tasks        = {}
    collapsed_uid          = nil

    filtered_tasks         = []
    filtered_parent_uids   = []
    filtered_parent_titles = []

    self.tasks.each_index do | index |

      task          = self.tasks[ index ]
      collapsed_uid = self.parent_uids[ index ][ 0..collapse_level ].join( ',' )

      if ( task.level <= collapse_level )

        # If this real task is already at the collapsing level, then just copy
        # it into the collapsed task hash.

        collapsed_task              = task.dup
        collapsed_tasks[ task.uid ] = collapsed_task

        # We rely on Ruby storing a reference to the same task structure here,
        # else later changes to the 'duration' field via the "collapsed_tasks"
        # hash won't be reflected in the "filtered_tasks" array.

        filtered_tasks         << collapsed_task
        filtered_parent_uids   << self.parent_uids[   index ].dup
        filtered_parent_titles << self.parent_titles[ index ].dup

      elsif ( collapsed_tasks.has_key?( collapsed_uid ) )

        # Have we generated this collapsed task UID before? Yes - just add
        # the current child task's duration to it.

        collapsed_tasks[ collapsed_uid ].duration += task.duration

      else

        # Generate a new collapsed task. Use the last two entries in the
        # titles array (noting Ruby array reference syntax meaning we have to
        # be careful of negative indices) for the new collapsed task's title.

        previous_level = collapse_level - 1
        previous_level = 0 if ( previous_level < 0 )

        collapsed_task = OpenStruct.new( {
          :level    => collapse_level,
          :uid      => collapsed_uid, # NB: See above - this is a string of one or more integers joined with a comma
          :tid      => task.tid,
          :title    => self.parent_titles[ index ][ previous_level..collapse_level ].join( ': ' ),
          :code     => Task.generate_xml_code( task.tid ),
          :duration => task.duration
        } )

        collapsed_tasks[ collapsed_uid ] = collapsed_task

        filtered_tasks         << collapsed_task
        filtered_parent_uids   << self.parent_uids[   index ][ 0..previous_level ]
        filtered_parent_titles << self.parent_titles[ index ][ 0..previous_level ]

      end
    end

    self.filtered_tasks         = filtered_tasks
    self.filtered_parent_uids   = filtered_parent_uids
    self.filtered_parent_titles = filtered_parent_titles
  end

  # Obtain a task list from the given parsed XML data (a REXML document).
  # Returns a hash with key :tasks, containing an array of task objects with
  # titles, codes and durations set up; :parent_uids, containing an array of
  # arrays of UIDs of the parent tasks (if any) for each entry in the :tasks
  # array; and :parent_titles, the same thing but holding parent strings for
  # display purposes.
  #
  # All strings are HTML-safe because they come from XML, so must use
  # character entities for sensitive characters just as in HTML. Views
  # should *not* further escape them with ERB::Util.h().
  #
  def self.get_tasks_from_xml( doc )

    # Extract details of every task into a flat array

    tasks = []

    doc.each_element( 'Project/Tasks/Task' ) do | task |
      begin
        tasks << OpenStruct.new( {
          :level => task.get_elements( 'OutlineLevel' )[ 0 ].text.to_i,
          :tid   => task.get_elements( 'ID'           )[ 0 ].text,
          :uid   => task.get_elements( 'UID'          )[ 0 ].text,
          :title => task.get_elements( 'Name'         )[ 0 ].text
        } )
      rescue
        # Ignore errors; they tend to indicate malformed tasks, or at least,
        # XML file task entries that we do not understand.
      end
    end

    # Step through the sorted tasks. Each time we find one where the
    # *next* task has an outline level greater than the current task,
    # then the current task MUST be a summary. Record its name and
    # blank out the task from the array. Otherwise, use whatever
    # summary name was most recently found (if any) as a name prefix.
    #
    # At each step, we keep a note of the titles and UIDs in the branch
    # leading up to a given task and push this "history" into a parent
    # title and UID array so that we can implement the 'collapse to level'
    # function later on, without having to refer back to the original
    # file (which is temporary and will have been deleted by then).

    prefix        = ''
    branch_uids   = []
    branch_titles = []
    parent_uids   = []
    parent_titles = []
    filled_to     = 0

    tasks.each_index do | index |
      task      = tasks[ index     ]
      next_task = tasks[ index + 1 ]

      branch_uids[   task.level ] = task.uid
      branch_titles[ task.level ] = task.title

      # Some XML files only contain tasks at strange levels with gaps -
      # particularly with nothing at level 0. Make sure we always fill these
      # in, else the parent title and collapse/filtering code will generate
      # strange task titles due to nil parent title entries.

      if ( task.level > filled_to )
        filled_to = task.level

        branch_titles.each_index do | level |
          title = branch_titles[ level ]
          if ( title.blank? )
            branch_titles[ level ] = "Untitled task at level #{ level }"
          end
        end
      end

      if ( next_task and next_task.level > task.level )
        prefix         = task.title
        tasks[ index ] = nil
      else
        top_level = task.level - 1
        top_level = 0 if ( top_level < 0 )

        parent_uids[   index ] = branch_uids[   0..top_level ]
        parent_titles[ index ] = branch_titles[ 0..top_level ]

        task.title = "#{ branch_titles[ top_level ] }: #{ task.title }" unless ( task.level.zero? )
      end
    end

    # Remove any 'nil' items we ended up with above.

    tasks.compact!
    parent_uids.compact!
    parent_titles.compact!

    # Now create a secondary array, where the UID of any given task is
    # the array index at which it can be found. This is just to make
    # looking up tasks by UID really easy, rather than faffing around
    # with "tasks.find { | task | task.uid = <whatever> }".
    #
    # By keeping track of the index in the original array too, we can
    # make sure the ordering (which has relevance in terms of input file
    # structure and the parent UID and title arrays) is maintained later.

    uid_tasks = {} # Using a hash means UIDs don't have to be numeric.

    tasks.each_index do | index |
      task = tasks[ index ]
      uid_tasks[ task.uid ] = { :task => task, :index => index }
    end

    # OK, now it's time to parse the assignments into some meaningful
    # array. These will become our timesheet system tasks. Assignments
    # which relate to empty elements in "uid_tasks" or which have zero
    # work are associated with tasks which are either summaries or
    # milestones. Ignore both types.

    real_tasks         = []
    real_parent_uids   = []
    real_parent_titles = []

    doc.each_element( 'Project/Assignments/Assignment' ) do | assignment |
      task_uid = assignment.get_elements( 'TaskUID' )[ 0 ].text
      data     = uid_tasks[ task_uid ]

      next if ( data.nil? )

      task     = data[ :task  ]
      index    = data[ :index ]
      work     = assignment.get_elements( 'Work' )[ 0 ].text

      # Parse the "Work" string: "PT<num>H<num>M<num>S", but with some
      # leniency to allow any data before or after the H/M/S stuff.

      strs = work.scan(/.*?(\d+)H(\d+)M(\d+)S.*?/).flatten
      hours, mins, secs = strs.map { | str | str.to_i }

      next if ( hours == 0 and mins == 0 and secs == 0 )

      # Woohoo, real task! Store it in 'real_tasks' at the same array index
      # as the item used to hold in the raw 'tasks' array.
      #
      # The divide by 3600.0 is VITAL to perform a floating point calculation
      # rather than rounding everything with integer maths.

      task.code     = Task.generate_xml_code( task.tid )
      task.duration = ( ( ( hours * 3600 ) + ( mins * 60 ) + secs ) / 3600.0 ).precision( 2 )

      real_tasks[         index ] = task
      real_parent_uids[   index ] = parent_uids[   index ]
      real_parent_titles[ index ] = parent_titles[ index ]
    end

    # Remove "nil" entries which exist beacuse of any tasks in the original
    # 'tasks' array which were discarded for some reason (e.g. no duration).

    real_tasks.compact!
    real_parent_uids.compact!
    real_parent_titles.compact!

    return {
      :tasks         => real_tasks,
      :parent_uids   => real_parent_uids,
      :parent_titles => real_parent_titles
    }
  end

private

  # Convert a hash from a forms submission, attempting to convey an array,
  # into an array. Returns the input item directly if given an array to start
  # with. Otherwise the hash's keys are treated as array indices and its
  # values as array entries.
  #
  def to_array( hash_or_array )
    return hash_or_array if ( hash_or_array.is_a? Array )

    array = []
    hash_or_array.each_pair do | key, value |
      array[ key.to_i ] = value
    end

    return array
  end

  # Take a hash as for "to_array", but where each array entry itself contains
  # another array similarly represented as a hash. Returns the nested array
  # result.
  #
  def to_nested_array( hash_or_array )
    hash_or_array = to_array( hash_or_array )
    hash_or_array.each_index do | index |
      hash_or_array[ index ] = to_array( hash_or_array[ index ] )
    end

    return hash_or_array
  end

  # Take a hash or array describing tasks and turn it into a true array of
  # Task-like objects (via OpenStruct representations). Return the result.
  #
  def to_task_array( hash_or_array )
    new_tasks = []
    tasks     = to_array( hash_or_array )

    # Make an OpenStruct representation of the entry at each array index so
    # that access later on is easier (via "task.property"). If a task entry is
    # already an OpenStruct it is just accepted as-is.

    tasks.each do | task |
      if ( task.is_a? OpenStruct )

        new_tasks << task

      else

        # Note how this code allows the structure to pick up anything in the
        # "task" data; that's important, since special additional flags can be
        # carried by the task data this way - e.g. an "import" flag. Callers
        # may rely on this (at the time of writing, the task import controller
        # does exactly that).

        struct          = OpenStruct.new( task )
        struct.level    = struct.level.to_i
        struct.duration = struct.duration.to_f
        struct.billable = ( struct.billable.to_i == 1 )
        new_tasks << struct

      end
    end

    return new_tasks
  end
end
