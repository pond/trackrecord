########################################################################
# File::    task_imports_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Import task definition data from external sources.
# ----------------------------------------------------------------------
#           30-Mar-2008 (ADH): Created.
########################################################################

class TaskImportsController < ApplicationController

  uses_prototype( :only => [ :create, :edit, :update ] )

  require 'zlib'
  require 'tempfile'
  require 'rexml/document'

  # Security.

  before_filter( :permitted? )

  # Take the file data from the 'new' view form and 'create' an "import
  # session"; that is, parse the file and generate an intermediate
  # representation of the tasks therein. Render an 'edit' view where the
  # user can 'edit' the "import session", by changing titles etc. of the
  # task list obtained from the file.
  #
  def create

    # Set up a new TaskImport session object and read the XML file details

    xmlfile = params[ :import ][ :xmlfile ] || ''
    @import = TaskImport.new
    @import.project_id = @current_user.control_panel.project_id

    if ( xmlfile == '' ) # Empty string = nothing chosen, else a file object

      flash[ :error ] = "Please choose a file before using the 'Analyse' button."

    else

      # The user selected a file to upload, so process it

      begin

        # We assume XML files always begin with "<" in the first byte and
        # if that's missing then it's GZip compressed. That's true in the
        # limited case of project files.

        xmlfile = xmlfile.tempfile
        byte = xmlfile.getc()
        xmlfile.rewind()

        xmlfile       = Zlib::GzipReader.new( xmlfile ) if ( byte != '<'[ 0 ] )
        xmldoc        = REXML::Document.new( xmlfile.read() )
        task_data     = TaskImport.get_tasks_from_xml( xmldoc )

        tasks         = task_data[ :tasks         ]
        parent_uids   = task_data[ :parent_uids   ]
        parent_titles = task_data[ :parent_titles ]

        if ( tasks.blank? )
          flash[ :error  ] = 'No usable tasks were found in that file'

        else
          @import.tasks         = tasks
          @import.parent_uids   = parent_uids
          @import.parent_titles = parent_titles
          @import.collapse      = @import.max_level

          @import.generate_filtered_task_list()

          flash[ :notice ] = 'Tasks read successfully. Please choose items to import.'
          render( { :action => :edit } )
          flash.delete( :notice ) and return # If not deleted, flash message persists for one fetch too many

        end

      rescue => error

        # REXML errors can be huge, including a full backtrace. It can cause
        # session cookie overflow and we don't want the user to see it. Cut
        # the message off at the first newline.

        lines = error.message.split("\n")
        flash[ :error ] = "Failed to read file: #{ lines[ 0 ] }"
        flash.delete( :notice ) # In case it got set above, but the render call then failed

      end
    end

    render( { :action => :new } )
    flash.delete( :error ) # If not deleted, flash message persists for one fetch too many
  end

  # Once the user has updated anything they need to update in the import
  # session 'edit'-like view (see also 'create' above), process the form
  # submission and import any real Tasks into the database if so requested
  # or re-process the input file if necessary.
  #
  def update

    @import = TaskImport.new( params[ :import ] )

    # Should this list now be collapsed, or should it be imported?

    unless ( params[ :do_collapse ].nil? )
      @import.generate_filtered_task_list()
      render( { :action => :edit } ) and return
    end

    # Import tasks from the filtered list submitted with the form, which holds
    # a combination of user-editable and hidden preset values.

    to_import = @import.filtered_tasks.reject { | task | task.import != '1' }

    if ( to_import.empty? )

      flash[ :error ] = 'No tasks were selected for import. Please select at least one task and try again.'

    else

      # Right, good to go! Do the import.

      begin
        Task.transaction do

          # Create a new project in passing?

          if params.has_key?( :do_import_new_task )
            project             = Project.new
            project.title       = @import.new_project_title
            project.customer_id = @import.new_project_customer_id
            project.description = "Created for XML bulk task import on #{ Time.now }"
            begin
              project.save!
            rescue => inner_error
              raise "Cannot create project: #{ inner_error }"
            end
          else
            project = Project.find( @import.project_id )
          end

          to_import.each do | source_task |
            Task.new do | destination_task |
              destination_task.title    = source_task.title
              destination_task.code     = source_task.code
              destination_task.duration = source_task.duration
              destination_task.billable = source_task.billable
              destination_task.project  = project
            end.save!
          end

          flash[ :notice ] = "#{ to_import.length } #{ to_import.length == 1 ? 'task' : 'tasks' } imported successfully."
          redirect_to( tasks_path() ) and return
        end

      rescue => error
        flash[ :error ] = "Unable to import tasks: #{ error }"

      end

    end

    render( { :action => :edit } )
    flash.delete( :error )
  end

private

  # Is the current action permitted?
  #
  def permitted?
    appctrl_not_permitted() if ( @current_user.restricted? )
  end
end
