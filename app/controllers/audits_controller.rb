########################################################################
# File::    audits_controller.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Manage Acts As Audited tables.
# ----------------------------------------------------------------------
#           20-Jan-2008 (ADH): Created.
########################################################################

class AuditsController < ApplicationController

  uses_prototype( :only => :index )

  # Security.

  before_filter( :permitted? )

  # List audit information.

  def index

    # Set up the column data; see the index helper functions in
    # application_helper.rb for details.

    @columns = [
      { :header_text  => 'When?',    :value_helper => :apphelp_created_at,       :sort_by => 'created_at'     },
      { :header_text  => 'Who?',     :value_helper => :audithelp_user_name,      :sort_by => 'users.name'     },
      { :header_text  => 'What?',    :value_helper => :audithelp_type_of_change, :sort_by => 'auditable_type' },
      { :header_text  => 'Changes',  :value_helper => :audithelp_changes,                                     },
      { :header_text  => 'Revision', :value_method => :version,
        :header_align => 'center',   :value_align  => 'center'                                                },
    ]

    # Get the basic options hash from ApplicationController, then handle
    # search forms.

    options         = appctrl_index_assist( Audited::Adapters::ActiveRecord::Audit )
    conditions_vars = {}

    search_num      = params[ :search ].to_i
    search_str      = "%#{ params[ :search ] }%" # SQL wildcards either side of the search string

    range_sql, range_start, range_end = appctrl_search_range_sql( Audited::Adapters::ActiveRecord::Audit )

    conditions_sql  = "WHERE #{ range_sql } ( action ILIKE :search_str OR auditable_type ILIKE :search_str OR users.name ILIKE :search_str OR version = :search_num )"
    conditions_vars = { :search_num => search_num, :search_str => search_str, :range_start => range_start, :range_end => range_end }

    # Sort order is already partially compiled in 'options' from the earlier
    # call to 'appctrl_index_assist'.

    order_sql = "ORDER BY #{ options[ :order ] }, created_at DESC"
    options.delete( :order )

    # Construct the query.

    finder_sql = "SELECT audits.* FROM audits\n" <<
                 "LEFT OUTER JOIN users ON ( audits.user_id = users.id )\n" <<
                  "#{ conditions_sql }\n" <<
                  "#{ order_sql      }"

    # Now paginate using this SQL query.

    @audits = Audited::Adapters::ActiveRecord::Audit.paginate_by_sql( [ finder_sql, conditions_vars ], options )
  end

private

  # Is the current action permitted?

  def permitted?
    appctrl_not_permitted() unless( @current_user.privileged? )
  end
end
