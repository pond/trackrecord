########################################################################
# File::    tasks_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Support functions for views related to Task objects. See
#           controllers/tasks_controller.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

module TasksHelper

  # Return HTML suitable for an edit form, providing a grouped list of
  # projects that can be assigned to the task. The list is grouped by
  # customer in default customer sort order, along with a 'None' entry
  # for unassigned projects. Pass the task object being edited.

  def taskhelp_project_selector( task )
    return apphelp_project_selector(
    'task_project_id',
    'task[project_id]',
    task.project_id
    )
  end

  # Return HTML showing the remaining hours on a task, or a label
  # indicating overrun. Pass the number of hours and the expected
  # task duration.

  def taskhelp_remaining( hours, duration )
    if ( hours > duration and duration != 0 )
      return '<span class="overrun">Overrunning</span>'
    else
      return apphelp_hours( 0 ) if ( duration == 0 )
      return apphelp_hours( duration - hours )
    end
  end

  # Return HTML showing the number of hours overrun on a task, or
  # a label indicating no overrun. Pass the number of hours and the
  # expected task duration.

  def taskhelp_overrun( hours, duration )
    if ( hours > duration and duration != 0 )
      return apphelp_hours( hours - duration )
    else
      return '<span class="no_overrun">None</span>'
    end
  end

  # Return a name of a given task's associated project, for use in list views.

  def taskhelp_project( task )
    reutnr '-' if ( task.project.nil? )
    return link_to( task.project.title, project_path( task.project ) )
  end

  # Return a name of a given task's associated customer, for use in list views.

  def taskhelp_customer( task )
    return '-' if ( task.project.nil? or task.project.customer.nil? )
    return link_to( task.project.customer.title, customer_path( task.project.customer ) )
  end

  # Return a formatted duration for the given task, for use in list views.

  def taskhelp_duration( task )
    return apphelp_string_hours( task.duration.to_s, '0', '?' )
  end

  # Return list actions appropriate for the given task.

  def taskhelp_actions( task )
    if ( @current_user.admin? or ( task.active and @current_user.manager? ) )
      actions = [ 'edit' ]
      actions.push( 'delete' ) if ( @current_user.admin? )
    else
      actions = []
    end

    actions.push( 'show' )
    return actions
  end

  # Return an HTML class name appropriate for a billable or not billable task
  # according to the given task or, if given a boolean, the value of that
  # boolean where 'true' means 'billable'
  #
  # Note that an additional class name may be included for active/inactive
  # tasks (but not when a boolean is given, obviously!).
  #
  def taskhelp_billable_class( task_or_boolean )
    task_or_boolean = task_or_boolean.billable if ( task_or_boolean.is_a?( Task ) )
    return ( task_or_boolean ? "task_billable" : "task_not_billable" )
  end

  # Return an HTML fragment giving help on billable versus non-billable tasks.
  #
  def taskhelp_billable_help
    "Names of billable or non-billable tasks are shown as follows: " <<
    "'<span class=\"#{ taskhelp_billable_class( true  ) }\">billable</span>', " <<
    "'<span class=\"#{ taskhelp_billable_class( false ) }\">not billable</span>'."
  end

  # As taskhelp_billable_class, but for active/inactive tasks.
  #
  def taskhelp_active_class( task_or_boolean )
    task_or_boolean = task_or_boolean.active if ( task_or_boolean.is_a?( Task ) )
    return ( task_or_boolean ? "task_active" : "task_inactive" )
  end

  # As taskhelp_billable_help, but for active/inactive tasks.
  #
  def taskhelp_active_help
    "Names of active or inactive tasks are shown as follows: " <<
    "'<span class=\"#{ taskhelp_active_class( true  ) }\">active</span>', " <<
    "'<span class=\"#{ taskhelp_active_class( false ) }\">inactive</span>'."
  end

  # Generate a YUI tree task selector. Pass a form builder object in the first
  # parameter (e.g. "bar" in "form_for @foo do | bar |"). The "object_name"
  # field is used to generate a unique ID and name for a hidden element which
  # carries IDs of selected YUI tree nodes, in the form "name[task_ids][]" - as
  # used by non-JS SELECT lists elsewhere. In the form submission processing
  # code, you must handle the use of special IDs in the YUI tree ("P" prefix
  # for Projects, "C" prefix for Customers, no prefix for tasks).
  #
  # In the next parameter optionally pass an options hash with keys and values
  # as shown below; any omitted key/value pair results in the described default
  # value being used instead.
  #
  #   Key              Meaning
  #   =========================================================================
  #   :inactive        If 'true', only inactive tasks, customers and projects
  #                    are shown in the selector. By default, only active items
  #                    will be shown.
  #
  #   :restricted_by   The task/project/customer list for currently logged in
  #                    users who are restricted is always restricted by that
  #                    user's permitted task list no matter what you set here.
  #                    If the current user is privileged, though, then passing
  #                    in a User object results in restriction by that user's
  #                    permitted task list. By default there is no restriction
  #                    so for privileged currently logged in users, all tasks
  #                    would be shown.
  #
  #   :included_tasks  If you know up-front a full list of tasks to show, then
  #                    pass them in here. Only items in the included list will
  #                    be shown. IDs get passed to the XHR handler, among other
  #                    things. This is NOT a security feature - see
  #                    ":restricted_by" for that.
  #
  #   :selected_tasks  An array of tasks to be initially selected in the tree.
  #                    May be empty. By default no tasks are selected. Ideally
  #                    the list should include no tasks that the current user
  #                    or 'restricted_by' key would hide, but if it does, they
  #                    simply won't be shown or selected and only the task IDs
  #                    will appear in HTML output.
  #
  #   :suffix_html     Beneath the text area gadget listing selected tasks is
  #                    a "Change..." link which pops up the Leightbox overlay
  #                    containing the YUI tree. If you want any extra HTML
  #                    inserted directly after the "</a>" of this link but
  #                    before the (hidden) DIV enclosing the tree, use this
  #                    option to include it. To keep things tidy, ensure that
  #                    the string is terminated by a newline ("\n") character.
  #
  #   :change_text     Speaking of the "Change..." link - alter its text with
  #                    this option, or omit for the default "Change..." string.
  #
  #   :params_name     Name to use in params instead of "task_ids", so that
  #                    instead of reading "params[form.object_name][:task_ids]"
  #                    in the controller handling the form submission, you read
  #                    the params entry corresponding to the given name.
  #
  # See also "taskhelp_degrading_selector" for JS/non-JS degrading code.
  #
  def taskhelp_tree_selector( form, options = {} )

    inactive       = options.delete( :inactive       )
    restricted_by  = options.delete( :restricted_by  )
    included_tasks = options.delete( :included_tasks )
    selected_tasks = options.delete( :selected_tasks ) || []
    suffix_html    = options.delete( :suffix_html    ) || ''
    change_text    = options.delete( :change_text    ) || 'Change...'
    params_name    = options.delete( :params_name    ) || :task_ids

    # Callers may generate trees restricted by the current user, but if that
    # user is themselves privileged their restricted task list will be empty
    # (because they can see anything). The simplest way to deal with this is
    # to clear the restricted user field in such cases.

    restricted_by = nil unless ( restricted_by.nil? || restricted_by.restricted? )

    # Based on the restricted task list - or otherwise - try to get at the root
    # customer array as easily as possible, trying to avoid pulling all tasks
    # out of the database. This is a bit painful either way, but usually a
    # restricted user will have a relatively small set of tasks assigned to
    # them so doing the array processing in Ruby isn't too big a deal.

    if ( @current_user.restricted? )
      permitted_tasks = @current_user.active_permitted_tasks()
    else
      permitted_tasks = restricted_by.active_permitted_tasks() unless ( restricted_by.nil? )
    end

    unless ( included_tasks.nil? )
      if ( permitted_tasks.nil? )
        permitted_tasks  = included_tasks
      else
        permitted_tasks &= included_tasks
      end
    end

    if ( permitted_tasks.nil? )
      root_customers = Customer.all
    else
      root_projects  = permitted_tasks.map { | task    | task.project     }.uniq
      root_customers = root_projects.map   { | project | project.customer }.uniq
    end

    # Reject items with no active / inactive tasks.

    method = inactive ? :inactive : :active

    root_customers.reject! do | customer |
      customer.tasks.send( method ).count.zero?
    end

    # Sort the root list by default order. Related associations are sorted
    # according to declarations made in the model code.

    Customer.apply_default_sort_order( root_customers )

    # Now take the selected task list and do something similar to get at the
    # selected project and customer IDs so we can build a complete list of the
    # node IDs to be initially expanded and checked in the YUI tree. The
    # customer list is sorted so that when the YUI tree starts expanding nodes,
    # it does it in display order from top to bottom - this looks better than
    # an arbitrary expansion order.

    selected_projects     = selected_tasks.map    { | task    | task.project     }.uniq
    selected_customers    = selected_projects.map { | project | project.customer }.uniq

    Customer.apply_default_sort_order( selected_customers )

    selected_task_ids     = selected_tasks.map     { | item | item.id         }
    selected_project_ids  = selected_projects.map  { | item | "P#{ item.id }" }
    selected_customer_ids = selected_customers.map { | item | "C#{ item.id }" }

    selected_ids = selected_customer_ids + selected_project_ids + selected_task_ids

    # Turn an included task list into IDs too, if present

    included_ids = ( included_tasks || [] ).map { | item | item.id }

    # Generate the root node data and extra XHR parameters to pass to the tree
    # controller in 'tree_controller.rb'.

    roots = root_customers.map do | customer |
      {
        :label  => customer.title,
        :isLeaf => false,
        :id     => "C#{ customer.id }"
      }
    end

    data_for_xhr_call  = []
    data_for_xhr_call << 'inactive' if ( inactive )
    data_for_xhr_call << "restrict,#{ restricted_by.id }" unless ( restricted_by.nil? )
    data_for_xhr_call << "include,#{ included_ids.join( '_' ) }" unless ( included_ids.empty? )

    # Create and (implicitly) return the HTML.

    id   = "#{ form.object_name }_#{ params_name }"
    name = "#{ form.object_name }[#{ params_name }][]"
    tree = yui_tree(
      :multiple             => true,
      :target_form_field_id => id,
      :target_name_field_id => "#{ id }_text",
      :name_field_separator => "\n", # Yes, a literal newline character
      :name_include_parents => ' &raquo; ',
      :name_leaf_nodes_only => true,
      :form_leaf_nodes_only => true,
      :expand               => selected_ids,
      :highlight            => selected_ids,
      :propagate_up         => true,
      :propagate_down       => true,
      :root_collection      => roots,
      :data_for_xhr_call    => data_for_xhr_call.join( ',' ),
      :div_id               => 'yui_tree_container_' << id
    ).gsub( /^/, '  ' )
    html = <<HTML
<textarea disabled="disabled" rows="5" cols="60" class="tree_selector_text" id="#{ id }_text">Task data loading...</textarea>
<br />
<a href="#leightbox_tree_#{ id }" rel="leightbox_tree_#{ id }" class="lbOn">#{ change_text }</a>
#{ suffix_html }<div id="leightbox_tree_#{ id }" class="leightbox">
  <a href="#" class="lbAction" rel="deactivate">Close</a>
  #{ taskhelp_billable_help }
  <p />
  #{ hidden_field_tag( id, selected_task_ids.join( ',' ), { :name => name } ) }
#{ tree }
  <a href="#" class="lbAction" rel="deactivate">Close</a>
</div>
HTML
  end

  # Create a degrading task selector using either a YUI tree or a SELECT list,
  # but not both. The latter has high database load. The former has greater
  # client requirements.
  #
  # The use cases for task selectors in Track Record are so varied that very
  # specific cases are handled with special-case code and HTML output may
  # include extra text to help the user for certain edge conditions, such as
  # a lack of any available tasks (in a timesheet editor, this may be because
  # all tasks are already added to the timesheet; for a user's choice of the
  # default list of tasks to show in timesheets, this may be because the user
  # has no permission to view any tasks; when configuring the tasks which a
  # restricted user is able to see, this may be because no active tasks exist).
  #
  # As a result, pass the reason for calling in the first parameter and an
  # options list in the second.
  #
  # Supported reasons are symbols and listsed in the 'case' statement in the
  # code below. Each is preceeded by comprehensive comments describing the
  # mandatory and (if any) optional key/value pairs which should go into the
  # options hash. Please consult these comments for more information.
  #
  # The following global options are also supported (none are mandatory):
  #
  #   Key           Value
  #   =====================================================================
  #   :line_prefix  A string to insert at the start of each line of output
  #                 - usually spaces, used if worried about the indentation
  #                 of the overall view HTML.
  #
  def taskhelp_degrading_selector( reason, options )
    output = ''
    form   = options.delete( :form )
    user   = options.delete( :user )

    case reason

      # Generate a selector used to add tasks to a given timesheet. Includes a
      # task selector and "add" button which submits to the given form with
      # name "add_row". The timesheet and form are specified in the options:
      #
      #   Key         Value
      #   =====================================================================
      #   :form       Prevailing outer form, e.g. the value of "f" in a view
      #               which has enclosed the call in "form_for :foo do | f |".
      #
      #               Leads to "task_ids" being invoked on the model associated
      #               with the form to determine which items, if any, must be
      #               initially selected for lists in the non-JS page version.
      #
      #   :timesheet  Instance of the timesheet being edited - used to find out
      #               which tasks are already included in the timesheet and
      #               thus which, if any, should be offered in the selector.
      #
      # NOTE: An empty string is returned if all tasks are already included in
      # the timesheet.
      #
      when :timesheet_editor
        tasks = timesheethelp_tasks_for_addition( options[ :timesheet ] )

        unless ( tasks.empty? )

          if ( session[ :javascript ].nil? )
            Task.sort_by_augmented_title( tasks )
            output << apphelp_collection_select( form, :task_ids, tasks, :id, :augmented_title )
            output << '<br />'
            output << form.submit( 'Add', { :name => 'add_row', :id => nil } )
          else
            output << taskhelp_tree_selector(
              form,
              {
                :included_tasks => tasks,
                :change_text    => 'Choose tasks...',
                :suffix_html    => " then #{ form.submit( 'add them', { :name => 'add_row', :id => nil } ) }\n"
              }
            )
          end

        end

      # Generate a selector used to add tasks to a given report. The report and
      # form are specified in the following options:
      #
      #   Key        Value
      #   =====================================================================
      #   :form      Prevailing outer form, e.g. the value of "f" in a view
      #              which has enclosed the call in "form_for :foo do | f |".
      #
      #              Leads to "task_ids" being invoked on the model associated
      #              with the form to determine which items, if any, must be
      #              initially selected for lists in the non-JS page version.
      #
      #   :report    Instance of the report being created - used to find out
      #              which tasks are already included in the report (for form
      #              resubmissions, e.g. from validation failure).
      #
      #   :inactive  If 'true', the selector is generated for inactive tasks
      #              only. If omitted or 'false', only active tasks are shown.
      #
      #   :name      A name to use instead of "task_ids" in the form submission
      #              - optional, required if you want multiple selectors in the
      #              same form.
      #
      # NOTE: All edge case conditions (no tasks, etc.) are handled internally
      # with relevant messages included in the HTML output for individual
      # selectors, but the caller ought to check that at least *some* tasks can
      # be chosen before presenting the user with a report generator form.
      #
      when :report_generator
        report =   options[ :report   ]
        active = ( options[ :inactive ] != true )
        field  = active ? :active_task_ids : :inactive_task_ids

        if ( session[ :javascript ].nil? )
          tasks = active ? Task.active() : Task.inactive()
          count = tasks.length
        else
          tasks = active ? report.active_tasks : report.inactive_tasks
          count = @current_user.all_permitted_tasks.count
        end

        if ( count.zero? )

          hint = active ? :active : :inactive
          output << "No #{ hint } tasks are available."

        else

          if ( session[ :javascript ].nil? )
            Task.sort_by_augmented_title( tasks )
            output << apphelp_collection_select(
              form,
              field,
              tasks,
              :id,
              :augmented_title
            )
          else
            output << taskhelp_tree_selector(
              form,
              {
                :selected_tasks => tasks,
                :params_name    => field,
                :inactive       => ! active
              }
            )
          end
        end

      # Generate a selector which controls the default task list shown in
      # new timesheets.
      #
      #   Key    Value
      #   =====================================================================
      #   :user  Instance of User model for the user for whom default timesheet
      #          options are being changed.
      #
      #   :form  Prevailing outer form, e.g. the value of "f" in a view
      #          which has enclosed the call in "form_for :foo do | f |".
      #          Typically this is used by a User configuration view, though,
      #          where a nested set of fields are being built via something
      #          like "fields_for :control_panel do | cp |". In such a case,
      #          use "cp" for the ":form" option's value.
      #
      #          This leads to "task_ids" being invoked on the model associated
      #          with the form to determine which items in the selection list,
      #          if any, must be initially selected in the non-JS page version.
      #
      # NOTE: All edge case conditions (no tasks, etc.) are handled internally
      # with relevant messages included in the HTML output.
      #
      when :user_default_task_list

        if ( user.active_permitted_tasks.count.zero? )

          # Warn that the user has no permission to see any tasks at all.

          output << "This account does not have permission to view\n"
          output << "any active tasks.\n"
          output << "\n\n"
          output << "<p>\n"

          # If the currently logged in user is unrestricted, tell them how to
          # rectify the above problem. Otherwise, tell them to talk to their
          # system administrator.

          if ( @current_user.restricted? )
            output << "  Please contact your system administrator for help.\n"
          else
            output << "  To enable this section, please assign tasks to\n"
            output << "  the user account with the security settings above\n"
            output << "  and save your changes. Then edit the user account\n"
            output << "  again to see the new permitted task list.\n"
          end

          output << "</p>"

        else

          if ( session[ :javascript ].nil? )
            tasks = user.active_permitted_tasks
            Task.sort_by_augmented_title( tasks )
            output << apphelp_collection_select( form, :task_ids, tasks, :id, :augmented_title )
          else
            output << taskhelp_tree_selector(
              form,
              {
                :restricted_by  => ( user.restricted? ) ? user : nil,
                :selected_tasks => user.control_panel.tasks
              }
            )
          end

        end

      # Generate a selector which controls the list of tasks the user is
      # permitted to see. Mandatory options:
      #
      #   Key    Value
      #   =====================================================================
      #   :user  Instance of User model for the user to whom task viewing
      #          permission is being granted or revoked.
      #
      #   :form  Prevailing outer form, e.g. the value of "f" in a view
      #          which has enclosed the call in "form_for :foo do | f |".
      #
      #          This leads to "task_ids" being invoked on the model associated
      #          with the form to determine which items in the selection list,
      #          if any, must be initially selected in the non-JS page version.
      #
      # NOTE: All edge case conditions (no tasks, etc.) are handled internally
      # with relevant messages included in the HTML output.
      #
      when :user_permitted_task_list
        return '' if ( @current_user.restricted? ) # Privileged users only!

        if ( Task.active.count.zero? )

          output << "There are no tasks currently defined. Please\n"
          output << "#{ link_to( 'create at least one', new_task_path() ) }."

        else

          if ( session[ :javascript ].nil? )
            tasks = Task.active()
            Task.sort_by_augmented_title( tasks )
            output << apphelp_collection_select( form, :task_ids, tasks, :id, :augmented_title )
          else

            # Don't use "user.[foo_]permitted_tasks" here as we *want* an empty
            # list for privileged accounts where no tasks have been set up.

            output << taskhelp_tree_selector(
              form,
              { :selected_tasks => user.tasks }
            )
          end

          unless ( user.restricted? )
            output << "\n\n"
            output << "<p>\n"
            output << "  This list is only enforced for users with a\n"
            output << "  'Normal' account type. It is included here\n"
            output << "  in case you are intending to change the account\n"
            output << "  type and want to assign tasks at the same time.\n"
            output << "</p>"
          end

        end
    end

    # All done. Indent or otherwise add a prefix to each line of output if
    # so required by the options and return the overall result.

    line_prefix = options.delete( :line_prefix )
    output.gsub!( /^/, line_prefix ) unless ( output.empty? || line_prefix.nil? )

    return output
  end
end
