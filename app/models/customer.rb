########################################################################
# File::    customer.rb
# (C)::     Hipposoft 2007
#
# Purpose:: Describe the behaviour of Customer objects. See below for
#           more details.
# ----------------------------------------------------------------------
#           24-Dec-2007 (ADH): Created.
########################################################################

class Customer < TaskGroup

  audited( :except => [
    :lock_version,
    :updated_at,
    :created_at,
    :id
  ] )

  USED_RANGE_COLUMN = 'created_at' # For the Rangeable base class of TaskGroup

  # Customers are people for whom work is done. Customers are involved
  # with various projects, which in turn include various tasks.

  has_many( :projects, { :order => Project::DEFAULT_SORT_ORDER } )
  has_many( :tasks,    { :through => :projects, :uniq => true  } )
  has_many( :control_panels )

  attr_protected(
    :project_ids,
    :control_panel_ids
  )

  # Some default properties are dynamic, so assign these here rather than
  # as defaults in a migration.
  #
  # Parameters:
  #
  #   Optional hash used for instance initialisation in the traditional way
  #   for an ActiveRecord subclass.
  #
  #   Optional User object. Default data from a user control panel may be used
  #   for the new object in future, though presently this parameter is ignored.
  #
  #
  def initialize( params = nil, user = nil )
    super( params )

    if ( params.nil? )
      self.active = true
      self.code   = "CID%04d" % Customer.count
    end
  end

  # Apply a default sort to the given array of customer objects. The array is
  # modified in place. Although this method is compatible with the default sort
  # mechanism in the YUI tree view component, it's not called by that because
  # the wider data set does not behave even remotely like acts_as_nested_set
  # style collections, so bespoke controller and view code is used to generate
  # arrays of objects.
  #
  def self.apply_default_sort_order( array )
    array.sort! { | x, y | x.title.downcase <=> y.title.downcase }
  end

  # Update an object with the given attributes. This is done by a
  # special model method because changes of the 'active' flag have
  # side effects for other associated objects. THE CALLER **MUST**
  # USE A TRANSACTION around a call to this method. There is no
  # need to call here unless the 'active' flag state is changing.
  # Pass in 'true' to update associated projects, else 'false' and
  # 'true' to update associated tasks via those projects (only if
  # updating projects too), else 'false'.
  #
  # Booleans default to 'true' if omitted.
  #
  def update_with_side_effects!( attrs, update_projects = true, update_tasks = true )
    active = self.active
    self.update_attributes!( attrs )

    # If the active flag has changed, deal with repercussions.

    if ( update_projects and attrs[ :active ] != active )
      self.projects.all.each do | project |
        project.update_with_side_effects!( { :active => attrs[ :active ] }, update_tasks )
      end
    end
  end

  # As update_with_side_effects!, but destroys things rather than
  # updating them. Pass 'true' to destroy associated projects, else
  # 'false'. If omitted, defaults to 'true'; pass also 'true' to
  # destroy tasks associated with those projects (only if destroying
  # projects too), else 'false'. Again, the default is 'true'.
  #
  def destroy_with_side_effects( destroy_projects = true, destroy_tasks = true )
    if ( destroy_projects )
      self.projects.all.each do | project |
        project.destroy_with_side_effects( destroy_tasks )
      end
    else
      Project.where( :customer_id => self.id ).update_all( :customer_id => nil )
    end

    self.destroy()
  end
end
