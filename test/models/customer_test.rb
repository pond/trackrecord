require File.dirname(__FILE__) + '/../test_helper'

class CustomerTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 28, Customer.count, "Wrong customer count"
  end

  # =========================================================================
  # More complicated data checks.
  # =========================================================================

  test "02 make sure customer metrics look sane" do
    assert_equal 16, Customer.active.count,   "Wrong active customer count"
    assert_equal 12, Customer.inactive.count, "Wrong inactive customer count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "03 basic model paranoia" do

    active   = Customer.active.first
    inactive = Customer.inactive.first

    assert_equal 0, inactive.control_panels.count, "Inactive customers should not feature in any Control Panels"

    active.projects.each do | project |
      assert_equal active.id, project.customer.id, "Customer <-> Project association failure"
    end

    active.tasks.each do | task |
      assert_equal active.id, task.project.try( :customer ).try( :id ), "Customer <-> Task association failure"
    end

    tasks = []
    active.projects.each do | project |
      tasks += project.tasks
    end

    tasks.uniq!
    tasks.sort!

    assert_equal tasks.map( &:id ).sort, active.tasks.map( &:id ).sort, "Unexpected customer task list"

    # Customer 26 just happens to have one assingned control panel

    c = Customer.find( 26 )
    assert_equal 1, c.control_panels.count, "Unexpected control panel count for customer"

    c.control_panels.each do | panel |
      assert_equal c.id, panel.customer.id, "Customer <-> Control Panel association failure"
    end

    # Basic creation

    c = Customer.new
    refute_nil c.code, "New customer has no assigned code"
    refute c.save, "A blank customer was saved"
    c.title = "New customer"
    assert c.save, "A valid customer could not be saved"

    c.destroy
  end

  # =========================================================================
  # Test different mechanisms for customer creation and protections against
  # assignment of inactive projects.
  # =========================================================================

  test "04 initializer variations and inactive projects" do
    c = Customer.new( :title => "Hello" )
    assert c.save, "A valid customer could not be saved"
    refute Customer.new( :title => "Hello" ).save, "A same-titled customer was saved unexpectedly"

    c.destroy
  end
  
  # =========================================================================
  # Test some general utility methods. Some of these come from the TaskGroup
  # base class so might end up re-tested elsewhere, but since code might be
  # updated in future and override TaskGroup methods, everything should still
  # be tested as if an independent functional unit.
  # =========================================================================

  test "06 utility methods" do

    # Augmented title method shouldn't crash for different titles
    # and customer assignments.

    c = Customer.new( :title => "New project" )
    assert_nothing_raised( "Method should never raise exceptions (A)" ) {
      c.augmented_title
    }

    Customer.all.each do | c |
      assert_nothing_raised( "Method should never raise exceptions (B)" ) {
        c.augmented_title
      }
    end

    # Test the "with side effects" stuff, including updates.

    c = Customer.active.first.dup
    c.title << " dup"
    c.projects = []
    assert c.save, "A valid customer could not be saved"

    Customer.active.first.projects.each do | project |
      assert project.active, "Project unexpectedly inactive"

      tasks = project.tasks

      project = project.dup
      project.title << " dup"
      assert project.save, "Cloned project could not be saved"
      c.projects << project

      project.tasks = []

      tasks.each do | task |
        assert task.active, "Task unexpectedly inactive"
        task = task.dup
        task.title << " dup"
        assert task.save, "Cloned task could not be saved"
        project.tasks << task
      end
    end

    # First, update active/inactive without updating the tasks.

    c.update_with_side_effects!( { :active => false }, false, false )
    c.reload
    refute c.active, "Expected customer to be inactive"

    c.projects.each do | project |
      assert project.active, "Project unexpectedly inactive"
    end

    c.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    # Now do the same, updating just the projects but not tasks.

    c.active = true
    assert c.save, "A valid customer could not be saved"

    projects = c.projects

    c.update_with_side_effects!( { :active => false }, true, false )
    c.reload
    refute c.active, "Expected customer to be inactive"

    c.projects.each do | project |
      refute project.active, "Project unexpectedly active"
    end

    c.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    # Finally, same thing but update everything

    c.active = true
    assert c.save, "A valid customer could not be saved"

    c.projects.each do | project |
      project.active = true
      project.save!
    end

    c.update_with_side_effects!( { :active => false }, true, true )
    c.reload
    refute c.active, "Expected customer to be inactive"

    c.projects.each do | project |
      refute project.active, "Project unexpectedly active"
    end

    c.tasks.each do | task |
      refute task.active, "Task unexpectedly active"
    end

    c.update_with_side_effects!( { :active => true }, true, true )
    c.reload
    assert c.active, "Expected customer to be active"

    c.projects.each do | project |
      assert project.active, "Project unexpectedly inactive"
    end

    c.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    # Now try destruction... First, just the Customer.

    projects = c.projects
    tasks = c.tasks

    c.destroy_with_side_effects( false, false )

    assert_raises( ActiveRecord::RecordNotFound, "Customer should not be reloadable after deletion" ) {
      c.reload
    }

    projects.each do | project |
      assert_nothing_raised( "Not-deleted project should reload successfully" ) {
        project.reload
      }
    end

    tasks.each do | task |
      assert_nothing_raised( "Not-deleted task should reload successfully" ) {
        task.reload
      }
    end

    # Now the Customer and Projects but not Tasks.

    c = Customer.active.first.dup
    c.title << " dup"
    c.projects = []
    assert c.save, "A valid customer could not be saved"

    c.projects = projects

    c.destroy_with_side_effects( true, false )

    assert_raises( ActiveRecord::RecordNotFound, "Customer should not be reloadable after deletion" ) {
      c.reload
    }

    projects.each do | project |
      assert_raises( ActiveRecord::RecordNotFound, "Project should not be reloadable after deletion" ) {
        project.reload
      }
    end

    tasks.each do | task |
      assert_nothing_raised( "Not-deleted task should reload successfully" ) {
        task.reload
      }
    end

    # Finally, delete everything.

    c = Customer.active.first.dup
    c.title << " dup"
    c.projects = []
    assert c.save, "A valid customer could not be saved"

    Customer.active.first.projects.each do | project |
      assert project.active, "Project unexpectedly inactive"

      tasks = project.tasks

      project = project.dup
      project.title << " dup"
      assert project.save, "Cloned project could not be saved"
      c.projects << project

      project.tasks = tasks
    end

    projects = c.projects
    tasks = c.tasks

    c.destroy_with_side_effects( true, true )

    assert_raises( ActiveRecord::RecordNotFound, "Customer should not be reloadable after deletion" ) {
      c.reload
    }

    projects.each do | project |
      assert_raises( ActiveRecord::RecordNotFound, "Project should not be reloadable after deletion" ) {
        project.reload
      }
    end

    projects.each do | task |
      assert_raises( ActiveRecord::RecordNotFound, "Task should not be reloadable after deletion" ) {
        task.reload
      }
    end

    assert_equal  28, Customer.count, "Wrong customer count after deletion"
    assert_equal 125, Project.count,  "Wrong project count after deletion"
    assert_equal 371, Task.count,     "Wrong task count after deletion"
  end

  # =========================================================================
  # Test permissions-related methods. Again, at the time of writing this is
  # pretty much all coming from TaskGroup but that might change in future and
  # the tests should still pass (or be updated, if the security model has
  # been changed too).
  # =========================================================================

  test "07 permissions" do
    
    # User 14 is a normal, restricted user with a permitted task list.
    
    u       = User.find( 14 )
    manager = User.managers.first
    admin   = User.admins.first
    
    assert_equal u.tasks.map( &:project ).uniq.map( &:customer ).uniq.sort, Customer.find_permitted( u                   ).sort, "Unexpected permitted customer list (A)"
    assert_equal u.tasks.map( &:project ).uniq.map( &:customer ).uniq.sort, Customer.find_permitted( u, :active => true  ).sort, "Unexpected permitted customer list (B)"
    assert_equal [],                                                        Customer.find_permitted( u, :active => false ).sort, "Unexpected permitted customer list (C)"
    
    # Managers and admins can see anything
    
    assert_equal Customer.all.sort,      Customer.find_permitted( admin                      ).sort, "Unexpected permitted customer list (D)"
    assert_equal Customer.active.sort,   Customer.find_permitted( admin,   :active => true   ).sort, "Unexpected permitted customer list (E)"
    assert_equal Customer.inactive.sort, Customer.find_permitted( admin,   :active => false  ).sort, "Unexpected permitted customer list (F)"
    
    assert_equal Customer.all.sort,      Customer.find_permitted( manager                    ).sort, "Unexpected permitted customer list (G)"
    assert_equal Customer.active.sort,   Customer.find_permitted( manager, :active => true   ).sort, "Unexpected permitted customer list (H)"
    assert_equal Customer.inactive.sort, Customer.find_permitted( manager, :active => false  ).sort, "Unexpected permitted customer list (I)"
    
    # Normal users can't modify customers, managers can only modify
    # active projects and admins can modify anything.
    
    Customer.all.each do | c | 
      refute c.can_be_modified_by?( u ), "Normal users should not be able to modify customers - see customer ID #{ c.id }"
      assert c.can_be_modified_by?( admin ), "Admins should be able to modify any customer - see customer ID #{ c.id }"
      assert_equal c.active, c.can_be_modified_by?( manager ), "Managers should only be able to modify active customers - see customer ID #{ c.id }"
    end
    
    # Normal users can only see customers with at least one project
    # containing at least one of the related tasks in the user's
    # permitted task list. Managers and admins can see anything.
    
    Customer.all.each do | c | 
      assert c.is_permitted_for?( admin   ), "Admins should be able to see any customer - see customer ID #{ c.id }"
      assert c.is_permitted_for?( manager ), "Managers should be able to see any customer - see customer ID #{ c.id }"
    
      permitted = ( c.tasks & u.tasks ).length > 0
      assert_equal permitted, c.is_permitted_for?( u ), "Normal user should not be able to see customer ID #{ c.id }"
    end
  end
end
