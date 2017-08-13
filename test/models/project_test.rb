require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 125, Project.count, "Wrong project count"
  end

  # =========================================================================
  # More complicated data checks.
  # =========================================================================

  test "02 make sure project metrics look sane" do
    assert_equal 50, Project.active.count,     "Wrong active project count"
    assert_equal 75, Project.inactive.count,   "Wrong inactive project count"
    assert_equal  0, Project.unassigned.count, "Wrong unassigned project count (A)"

    # Database checks for multiple AREL-based conditions in potentially
    # differing orders.

    active = Project.active.first
    active_customer = active.customer
    active.customer = nil
    active.save!

    assert_equal 1, Project.unassigned.count, "Wrong unassigned project count (B)"
    assert_equal 1, Project.active.unassigned.count, "Wrong active unassigned project count (A)"
    assert_equal 1, Project.unassigned.active.count, "Wrong active unassigned project count (B)"
    assert_equal 0, Project.inactive.unassigned.count, "Wrong inactive unassigned project count (A)"
    assert_equal 0, Project.unassigned.inactive.count, "Wrong inactive unassigned project count (B)"

    inactive = Project.inactive.first
    inactive_customer = inactive.customer
    inactive.customer = nil
    inactive.save!

    assert_equal 2, Project.unassigned.count, "Wrong unassigned project count (C)"
    assert_equal 1, Project.active.unassigned.count, "Wrong active unassigned project count (C)"
    assert_equal 1, Project.unassigned.active.count, "Wrong active unassigned project count (D)"
    assert_equal 1, Project.inactive.unassigned.count, "Wrong inactive unassigned project count (C)"
    assert_equal 1, Project.unassigned.inactive.count, "Wrong inactive unassigned project count (D)"

    active.customer = active_customer
    active.save!

    assert_equal 1, Project.unassigned.count, "Wrong unassigned project count (D)"
    assert_equal 0, Project.active.unassigned.count, "Wrong active unassigned project count (E)"
    assert_equal 0, Project.unassigned.active.count, "Wrong active unassigned project count (F)"
    assert_equal 1, Project.inactive.unassigned.count, "Wrong inactive unassigned project count (E)"
    assert_equal 1, Project.unassigned.inactive.count, "Wrong inactive unassigned project count (F)"

    inactive.customer = inactive_customer
    inactive.save!

    assert_equal 0, Project.unassigned.count, "Wrong unassigned project count (E)"
    assert_equal 0, Project.active.unassigned.count, "Wrong active unassigned project count (G)"
    assert_equal 0, Project.unassigned.active.count, "Wrong active unassigned project count (H)"
    assert_equal 0, Project.inactive.unassigned.count, "Wrong inactive unassigned project count (G)"
    assert_equal 0, Project.unassigned.inactive.count, "Wrong inactive unassigned project count (H)"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "03 basic model paranoia" do

    # Check known associations

    p = Project.find( 3 )

    assert_equal 7, p.tasks.count, "Wrong project task count"
    assert_equal 2, p.control_panels.count, "Wrong project control panel count"

    assert p.control_panels.first.user.control_panel.project == p, "Association failure (A)"
    assert p.tasks.first.project == p, "Association failure (B)"

    # Basic creation

    p = Project.new
    refute_nil p.code, "New project has no assigned code"
    refute p.save, "A blank project was saved"
    p.title = "New project"
    assert p.save, "A valid project could not be saved"

    p.destroy
  end

  # =========================================================================
  # Test different mechanisms for project creation and protections against
  # assignment of inactive projects.
  # =========================================================================

  test "04 initializer variations and inactive projects" do
    p = Project.new( :title => "Hello" )
    assert p.save, "A valid project could not be saved"
    refute Project.new( :title => "Hello" ).save, "A same-titled project was saved unexpectedly"

    p.destroy

    # Get a user with a control panel that specifies a customer to assign
    # to new tasks by default. The customer must be active.

    admin = User.admins.first
    customer = admin.control_panel.customer = Customer.active.first
    admin.control_panel.save!

    p = Project.new( nil, admin )
    assert_equal customer, p.customer, "New for-user project has unexpected customer"
    p.title = "New project"
    assert p.save, "A valid project could not be saved"

    p.destroy

    # Temporarily change the user's control panel customer to be inactive.

    customer.active = false
    customer.save!

    p = Project.new( nil, admin )
    p.title = "New project"
    assert_nil p.customer, "New for-user project was assigned an inactive customer"
    assert p.save, "A valid project could not be saved"

    p.destroy

    # Force the issue by attempting to assign the project manually.

    p = Project.new( nil, admin )
    p.title = "New project"
    p.customer = customer
    refute p.save, "A invalid project with an inactive customer was saved"
    assert_equal "Active projects can only be associated with active customers", p.errors.try( :messages ).try( :[], :base ).try( :[], 0 ), "Expected error message not present"

    customer.active = true
    customer.save!
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

    p = Project.new( :title => "New project" )
    assert_nothing_raised( "Method should never raise exceptions (A)" ) {
      p.augmented_title
    }

    p.customer = Customer.active.first
    assert_nothing_raised( "Method should never raise exceptions (B)" ) {
      p.augmented_title
    }

    Project.all.each do | p |
      assert_nothing_raised( "Method should never raise exceptions (C)" ) {
        p.augmented_title
      }
    end

    # Test the "with side effects" stuff, including updates.

    p = Project.active.first.dup
    p.title << " dup"

    tasks = []

    Project.active.first.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
      task = task.dup
      task.title << " dup"
      assert task.save, "Cloned task could not be saved"
      tasks << task
    end

    p.tasks = tasks

    assert p.save, "A valid project could not be saved"

    # First, update active/inactive without updating the tasks.

    p.update_with_side_effects!( { :active => false }, false )
    p.reload
    refute p.active, "Expected project to be inactive"
    
    p.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    # Now do the same, updating the tasks.

    p.active = true
    assert p.save, "A valid project could not be saved"

    p.update_with_side_effects!( { :active => false }, true )
    p.reload
    refute p.active, "Expected project to be inactive"

    p.tasks.each do | task |
      refute task.active, "Task unexpectedly active"
    end

    p.update_with_side_effects!( { :active => true }, true )
    p.reload
    assert p.active, "Expected project to be active"

    p.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    # Now try destruction...

    tasks = p.tasks

    p.destroy_with_side_effects( false )

    assert_raises( ActiveRecord::RecordNotFound, "Project should not be reloadable after deletion" ) {
      p.reload
    }

    tasks.each do | task |
      assert_nothing_raised( "Not-deleted task should reload successfully" ) {
        task.reload
      }
    end

    p = Project.active.first.dup
    p.title << " dup"
    p.tasks = []
    assert p.save, "A valid project could not be saved"

    p.tasks = tasks
    p.tasks.each do | task |
      assert task.active, "Task unexpectedly inactive"
    end

    p.destroy_with_side_effects( true )

    assert_raises( ActiveRecord::RecordNotFound, "Project should not be reloadable after deletion" ) {
      p.reload
    }

    tasks.each do | task |
      assert_raises( ActiveRecord::RecordNotFound, "Task should not be reloadable after deletion" ) {
        task.reload
      }
    end

    assert_equal 125, Project.count, "Wrong project count after deletion"
    assert_equal 371, Task.count,    "Wrong task count after deletion"
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

    assert_equal u.tasks.map( &:project ).uniq.sort, Project.find_permitted( u                   ).sort, "Unexpected permitted project list (A)"
    assert_equal u.tasks.map( &:project ).uniq.sort, Project.find_permitted( u, :active => true  ).sort, "Unexpected permitted project list (B)"
    assert_equal [],                                 Project.find_permitted( u, :active => false ).sort, "Unexpected permitted project list (C)"

    # Managers and admins can see anything

    assert_equal Project.all.sort,      Project.find_permitted( admin                      ).sort, "Unexpected permitted project list (D)"
    assert_equal Project.active.sort,   Project.find_permitted( admin,   :active => true   ).sort, "Unexpected permitted project list (E)"
    assert_equal Project.inactive.sort, Project.find_permitted( admin,   :active => false  ).sort, "Unexpected permitted project list (F)"

    assert_equal Project.all.sort,      Project.find_permitted( manager                    ).sort, "Unexpected permitted project list (G)"
    assert_equal Project.active.sort,   Project.find_permitted( manager, :active => true   ).sort, "Unexpected permitted project list (H)"
    assert_equal Project.inactive.sort, Project.find_permitted( manager, :active => false  ).sort, "Unexpected permitted project list (I)"

    # Normal users can't modify projects, managers can only modify
    # active projects and admins can modify anything.

    Project.all.each do | p | 
      refute p.can_be_modified_by?( u ), "Normal users should not be able to modify projects - see project ID #{ p.id }"
      assert p.can_be_modified_by?( admin ), "Admins should be able to modify any project - see project ID #{ p.id }"
      assert_equal p.active, p.can_be_modified_by?( manager ), "Managers should only be able to modify active projects - see project ID #{ p.id }"
    end

    # Normal users can only see projects with at least one of the
    # project tasks in the user's permitted task list. Managers and
    # admins can see anything.

    Project.all.each do | p | 
      assert p.is_permitted_for?( admin   ), "Admins should be able to see any project - see project ID #{ p.id }"
      assert p.is_permitted_for?( manager ), "Managers should be able to see any project - see project ID #{ p.id }"

      permitted = ( p.tasks & u.tasks ).length > 0
      assert_equal permitted, p.is_permitted_for?( u ), "Normal user should not be able to see project ID #{ p.id }"
    end
  end
end
