require 'test_helper'
require 'capybara/poltergeist'

class TimesheetEditorNoJsTest < ActionDispatch::IntegrationTest

  test "001 row addition" do
    current_user = thelper_sign_in()
    visit new_timesheet_path()
    all( :xpath, '//input[@type="submit"]' ).first.click

    # Select all tasks in the selection box to prove that they're present,
    # then deselect the last few.

    available_to_select = Task.active.all - current_user.control_panel.tasks

    available_to_select.each do | task |
      page.select( task.augmented_title, :from => 'timesheet_task_ids' )
    end

    count_to_deselect = available_to_select.count * 0.2

    # Note how we shorten "available_to_select" in passing. Only the selected
    # tasks remain.

    1.upto( count_to_deselect ) do | index |
      task = available_to_select.pop()
      page.unselect( task.augmented_title, :from => 'timesheet_task_ids' )
    end

    # Now add the selected tasks and make sure it worked.

    find( :xpath, '//input[@name="add_row"]' ).click

    assert_equal count_to_deselect, page.all( :css, '#timesheet_task_ids option' ).count, 'Task addition selection list has unexpected content'

    # This runs *very* slowly over the full task set :-( so only do a few

    1.upto( 10 ) do
      task = available_to_select.sample()
      assert page.has_content?( task.title ), "Task title '#{ task.title }' not found in page"
    end
  end

end
