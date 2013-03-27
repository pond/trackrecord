########################################################################
# File::    task_imports_helper.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Support functions for views related to Task Import objects.
#           See controllers/task_imports_controller.rb for more.
# ----------------------------------------------------------------------
#           04-Jan-2008 (ADH): Created.
########################################################################

module TaskImportsHelper

  # Generate a project selector for the project to which imported tasks will
  # be assigned. HTML is output which is suitable for inclusion in a table
  # cell or other similar container. Pass the form object being used for the
  # task import view and optional string to add as a prefix to each line of
  # output.
  #
  # At least one active project must exist when this method is called, else
  # the output string will be empty.
  #
  def timphelp_project_selector( form, line_prefix = '' )
    unless ( Project.active.count.zero? )
      output = apphelp_project_selector(
                 'import_project_id',
                 'import[project_id]',
                 @current_user.control_panel.project_id
               ).gsub( /^/, line_prefix )
    else
      output = ''
    end

    return output
  end

  # Generate a selector menu for collapsing a task tree to a given level. Pass
  # the containing form, the maximum integer level to show and an optional
  # string to add as a prefix to each line of output.
  #
  def timphelp_collapse_selector( form, max_level, line_prefix = '' )
    levels = []

    0.upto( max_level ) do | level |
      levels[ level ] = [ "Outline level #{ level }", level ]
    end

    return apphelp_select(
             form,
             :collapse,
             levels,
             false
           ).gsub( /^/, line_prefix )
  end
end
