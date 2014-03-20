require 'test_helper'

class NestedInitialItemCreationTest < ActionDispatch::IntegrationTest

  test "001 create a project without a task" do
    thelper_sign_in

    # Follow the control panel "manage projects" link, then the "add project"
    # link, as a user would.

    click_link(nil, :href => projects_path)
    click_link(nil, :href => new_project_path)

    # First just submit with nothing, to verify title validation worked

    thelper_submit_with_named_button
    thelper_assert_has_form_error

    # Now fill in the title - the rest we don't care about, except for there
    # being sufficient default data for no more errors - then make sure that
    # only the project count increased.

    project_count = Project.count
    task_count = Task.count

    fill_in :project_title, with: "Test mode project, no task"
    thelper_submit_with_named_button

    assert_equal project_count + 1, Project.count
    assert_equal task_count, Task.count

    # Make sure the project as-is validates successfully. We expect a title
    # and code. Since the fixture data is assumed to associate a default
    # assigned customer with the admin user, we expect a valid customer too.

    project = Project.reorder( "created_at DESC" ).first
    assert_not_nil project.title
    assert_not_nil project.code
    assert_not_nil project.customer
    assert project.active, "New project should be active"
    assert_equal 0, project.tasks.count
  end

  test "002 create a project with a task" do
    thelper_sign_in

    # As test 001, but fill in a task title and check the resuting data.

    click_link(nil, :href => projects_path)
    click_link(nil, :href => new_project_path)

    project_count = Project.count
    task_count = Task.count

    fill_in :project_title, with: "Test mode project, with task"
    fill_in :project_tasks_attributes_0_title, with: "Test mode nested task"
    thelper_submit_with_named_button

    assert_equal project_count + 1, Project.count
    assert_equal task_count + 1, Task.count

    project = Project.reorder( "created_at DESC" ).first
    assert_not_nil project.title
    assert_not_nil project.code
    assert_not_nil project.customer
    assert project.active, "New project should be active"
    assert_equal 1, project.tasks.count

    task = Task.reorder( "created_at DESC" ).first
    assert_equal project.tasks.first, task
    assert_equal task.project, project
    assert_not_nil task.title
    assert_not_nil task.code
    assert_equal BigDecimal.new( '0' ), task.duration
    assert task.active, "Auto-created task should be active"
    refute task.billable, "Auto-created task should not be billable"
  end

  test "003 create a customer without a project" do
    thelper_sign_in

    # As test 001, but create a customer without an initial project.

    click_link(nil, :href => customers_path)
    click_link(nil, :href => new_customer_path)

    thelper_submit_with_named_button
    thelper_assert_has_form_error # ...since no title was given

    customer_count = Customer.count
    project_count = Project.count

    fill_in :customer_title, with: "Test mode customer, no project"
    thelper_submit_with_named_button

    assert_equal customer_count + 1, Customer.count
    assert_equal project_count, Project.count

    customer = Customer.reorder( "created_at DESC" ).first
    assert_not_nil customer.title
    assert_not_nil customer.code
    assert customer.active, "New customer should be active"
    assert_equal 0, customer.projects.count
  end

  test "004 create a customer with a project" do
    thelper_sign_in

    # As test 003, but fill in a project title and check the resuting data.

    click_link(nil, :href => customers_path)
    click_link(nil, :href => new_customer_path)

    customer_count = Customer.count
    project_count = Project.count

    fill_in :customer_title, with: "Test mode customer, with project"
    fill_in :customer_projects_attributes_0_title, with: "Test mode nested project"
    thelper_submit_with_named_button

    assert_equal customer_count + 1, Customer.count
    assert_equal project_count + 1, Project.count

    customer = Customer.reorder( "created_at DESC" ).first
    assert_not_nil customer.title
    assert_not_nil customer.code
    assert customer.active, "New customer should be active"
    assert_equal 1, customer.projects.count

    project = Project.reorder( "created_at DESC" ).first
    assert_equal customer.projects.first, project
    assert_equal project.customer, customer
    assert_not_nil project.title
    assert_not_nil project.code
    assert project.active, "Auto-created project should be active"
  end
end
