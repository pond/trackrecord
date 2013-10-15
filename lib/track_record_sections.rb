########################################################################
# File::    track_record_sections.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Mixin providing abstract section handling for various bits
#           of TrackRecord code. Sections are defined in terms of an
#           array of tasks in some pre-sorted order. Going from one task
#           to the next, in order, may cause a new project and / or
#           customer to be encountered related to that task; in such a
#           case, the task is deemed to mark the start of a new section.
#
#           A similar concept is used for groups, but groups are based
#           on task names. If a task title includes a colon character,
#           then its group name is the title up to but excluding the
#           first colon; else the group name is the whole task title.
#           This is most often useful when used with bulk task import.
#
#           Both sections and groups are typically used for visual
#           purposes when showing things like reports or timesheets. The
#           calling code can associate data with group and section info,
#           allowing it to independently maintain related information
#           (such as as per-section worked hour totals in reports) if
#           so required.
# ----------------------------------------------------------------------
#           30-Jun-2008 (ADH): Created.
#           09-Aug-2013 (ADH): Complete API redesign to fit new fast
#                              report mechanism. Much cleaner now.
########################################################################

module TrackRecordSections

  # All the guts of a Section class inside a module, so multiple
  # inheritance-like behaviour can be used for Reports which need
  # both Section-like and Row < Calculator-like objects to keep
  # per-section totals.
  #
  module SectionMixin
    attr_reader :project, :customer, :identifier

    # Initialize a section by passing in a unique identifier of your choice
    # and a Project instance (may be nil if this section has no project or
    # customer).
    #
    def initialize_section( identifier, project )
      @identifier = identifier
      @project    = project
      @customer   = project.try( :customer )
    end

    # Returns a representation of the section title, based on the customer and
    # project data passed to the constructor. Returns HTML-safe HTML data by
    # default, or pass 'true' in the optional second parameter to return plain
    # text only with no escaping (e.g. for CSV output, or any other non-HTML
    # format).
    #
    # The method requires access to helper functions, such as "link_to" or
    # "ApplicationHelper". This is done via a context object you pass in via
    # the mandatory first parameter. If you're calling here from ERB code in a
    # view, simply pass "self" here:
    #
    #   <%= section.title( self ) %>
    #
    def title( context, plain_text = false )
      if ( @project.nil? )
        return 'No customer, no project'
      elsif ( @customer.nil? )
        if ( plain_text )
          return "(No customer) #{ @project.title }"
        else
          return "(No customer) #{ context.apphelp_augmented_link( @project ) }".html_safe()
        end
      else
        if ( plain_text )
          return "Customer #{ @customer.title } - #{ @project.title }"
        else
          return "Customer #{ context.apphelp_augmented_link( @customer ) } - #{ context.apphelp_augmented_link( @project ) }".html_safe()
        end
      end
    end
  end

  # Represent a single report, timesheet etc. section. Usually instantiation
  # is done only by the Sections class. Callers obtain references to instances
  # only by enumeration or access methods again in the Sections class.
  #
  class Section
    include SectionMixin

    def initialize( identifier, project )
      initialize_section( identifier, project )
    end
  end

  # All the guts of a Group class inside a module, mostly for consistency of
  # implementation compared with the Section and Sections classes.
  #
  module GroupMixin
    attr_reader :task

    # Initialize a group by passing in a non-nil Task instance.
    #
    def initialize_group( task )
      @task = task
    end

    # Returns the group title, in plain text.
    #
    def title
      this_group = nil
      task_title = @task.title || ''
      colon      = task_title.index( ':' )
      this_group = task_title[ 0..( colon - 1 ) ] unless ( colon.nil? )

      return this_group
    end
  end

  # Represent a single report, timesheet etc. group. Usually instantiation
  # is done only by the Sections class. Callers obtain references to instances
  # only by enumeration or access methods again in the Sections class.
  #
  class Group
    include GroupMixin

    def initialize( task )
      initialize_group( task )
    end
  end

  # All the guts of a Sections class inside a module, so multiple
  # inheritance-like behaviour can be used for Reports which expose
  # the Sections interface herein, along with their own Calculator
  # interface for overall totals.
  #
  module SectionsMixin

    # Initialize by passing in the array of non-nil Task instances that 
    # will be used for group and section processing. This must already
    # be in an order that makes sense for such processing, e.g. sorted
    # by project, customer, task title.
    #
    # Ideally, pass an ActiveRecord::Relation instance that'll return a
    # set of appropriately sorted objects for most efficient operation.
    #
    # In the optional section parameter, pass a Class which will be
    # instantiated instead of TrackRecordSections::Section whenever a
    # new section is being defined. The class must include SectionMixin
    # along with whatever other behaviour it might define (which is of
    # interest only to the caller and ignored herein). The custom
    # class constructor must have the same signature as, and must call
    # module method "initialize_section()".
    #
    def initialize_sections( tasks, optionalClass = Section )

      # Create new Section objects and a map between task IDs and
      # those objects, so we can get to them quickly.
      #
      # We run through the tasks in the array order. Whether or
      # not a task needs a new Section object instance, because
      # it represents a hithertoo unencountered project/customer
      # combination, tells us that this task's row will sit at
      # the top of a new section in e.g. a generated report. Keep
      # track of that flag in another task-keyed hash as it'll be
      # very useful for section-aware generators or similar views.
      #
      # Groups are also handled in this loop, creating a set of
      # flags, but not needing new section objects. While sections
      # are uniquely identified by a combination of project and
      # customer, groups are uniquely identified by title. Group
      # titles are based upon the presence of colon characters in
      # task names (everything up to the first colon).

      @task_to_section_map = {}
      @task_starts_section = {}
      @sections            = {}
      section_identifier   = 0

      # Groups are harder as we have to consider the no-colon-in-title
      # "ungrouped" tasks and how we need to treat it as a group change
      # if we change from ungrouped to group task, or vice versa.

      @task_to_group_map   = {}
      @task_starts_group   = {}
      @groups              = {}
      previous_group_id    = nil # Intentional potential first-row match to "ungrouped" task

      tasks.each do | task |
        task_id_str = task.id.to_s

        project_id  = task.project.try( :id ) || '-'
        customer_id = task.project.try( :customer ).try( :id ) || '-'
        section_id  = "#{ customer_id }_#{ project_id }"
        found       = @sections[ section_id ]

        if ( found.nil? )
          @task_starts_section[ task_id_str ] = true
          @task_to_section_map[ task_id_str ] = @sections[ section_id ] = optionalClass.new( section_identifier += 1, task.project )
        else
          @task_starts_section[ task_id_str ] = false
          @task_to_section_map[ task_id_str ] = found
        end

        group    = Group.new( task )
        group_id = group.title()
        found    = @groups[ group_id ]

        if ( found.nil? )
          @task_starts_group[ task_id_str ] = true
          @task_to_group_map[ task_id_str ] = @groups[ group_id ] = group
        else
          @task_starts_group[ task_id_str ] = ( previous_group_id != group_id )
          @task_to_group_map[ task_id_str ] = found
        end

        previous_group_id = group_id
      end
    end

    # Obtain a Section instance related to the given task, specified as
    # a task ID in string form.
    #
    def section( task_id_str )
      @task_to_section_map[ task_id_str ]
    end

    # Returns 'true' if the given task, specified as a task ID in string
    # form, starts a new Section.
    #
    def starts_new_section?( task_id_str )
      @task_starts_section[ task_id_str ]
    end

    # Obtain a Group instance related to the given task, specified as
    # a task ID in string form.
    #
    def group( task_id_str )
      @task_to_group_map[ task_id_str ]
    end
    
    # Returns 'true' if the given task, specified as a task ID in string
    # form, starts a new Group.
    #
    def starts_new_group?( task_id_str )
      @task_starts_group[ task_id_str ]
    end

    # For the given task, which must be an instance present in the array
    # of tasks given in the constructor, retrieve an array containing in
    # order first to last index: a Section, a flag indicating that the
    # task started a new Section if true, a Group and a flag indicating
    # that the task started a new Group if true.
    #
    # The task must be specified by its ID, as a string.
    #
    def retrieve( task_id_str )
      [
        @task_to_section_map[ task_id_str ],
        @task_starts_section[ task_id_str ],
        @task_to_group_map  [ task_id_str ],
        @task_starts_group  [ task_id_str ]
      ]
    end

    # Iterate over the tasks provided in the constructor, in the same
    # order as provided in the construtor. The caller's block is invoked
    # with parameters of the task, a Section, a flag indicating that the
    # task started a new Section if true, a Group and a flag indicating
    # that the task started a new Group if true.
    #
    def each_task
      tasks.each do | task |
        section, is_new_section, group, is_new_group = retrieve( task.id.to_s )
        yield( task, section, is_new_section, group, is_new_group )
      end
    end

    # Retrieve all Sections, perhaps in order to assign caller data.
    # Call with a block, invoked with a Section instance at each iteration.
    # The returned Section order is arbitrary. Use e.g. "iterate()" for
    # deterministic ordering.
    #
    def each_section
      @sections.each_value do | section |
        yield( section )
      end
    end

    # As "each_section()", but for Groups.
    #
    def each_group
      @groups.each_value do | group |
        yield( group )
      end
    end

    # If you want to change the task list at some later time, with some
    # tasks omitted, call here to retain all section and group data but
    # reasses the "this task starts a new section/group" flag settings
    # in view of the new task list.
    #
    # The new task list can be a reordered version of the original and
    # can have tasks omitted from the original, but may contain no new
    # tasks. Results are undefined in such a case.
    #
    # The internal record of the task list is necessarily updated (else
    # it would mismatch the flags) so the "each_task" enumerator will,
    # after calling here, return the new tasks list, not the original.
    #
    def reassess_start_flags_using( tasks )
      previous_section = nil
      previous_group   = nil

      tasks.each do | task |
        task_id_str = task.id.to_s
        s           = section( task_id_str )
        g           = group( task_id_str )

        @task_starts_section[ task_id_str ] = ( s != previous_section )
        @task_starts_group  [ task_id_str ] = ( g != previous_group   )

        previous_section = s
        previous_group   = g
      end
    end

  end

  # The Sections class processes an array of Task instances provided by
  # the instantiating caller. It determines where new Section or Group
  # instances apply, in the context of running through the given Task
  # array in order from first element to last.
  #
  # Iterators and direct accessors are provided to get at processed
  # Section and Group information.
  #
  class Sections
    include SectionsMixin

    def initialize( tasks )
      initialize_sections( tasks )
    end
  end
end