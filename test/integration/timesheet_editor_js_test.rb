require 'test_helper'
require 'capybara/poltergeist'

class TimesheetEditorJsTest < ActionDispatch::IntegrationTest

  test '001 row addition' do
    thelper_enable_javascript_for_this_test()

    thelper_sign_in()
    visit new_timesheet_path()
    all( :xpath, '//input[@type="submit"]' ).first.click

    # Click on the magic JS-driven link that says "Choose tasks..." in English

    find( :xpath, '//a[@href="#leightbox_tree_timesheet_task_ids"]').click

    # This cryptic ID is YUI Tree for 'first outermost checkbox'; we expect
    # one and click on it, selecting the top level item and its subtrees.
    # These have to be fetched by AJAX, which can take a while...

    page.assert_selector( '#ygtvcontentel1', :count => 1 )
    find( '#ygtvcontentel1' ).click

    # Make Capybara wait for some text we're expecting.

    expected_title = Customer.active.first.projects.active.last.tasks.active.last.title
    assert page.has_content?( expected_title ), "Couldn't find task title '#{ expected_title }' expected in YUI tree"

    # Close the pop-up using the Leightbox action class link and make sure
    # that the text area has the expected number of entries.

    all( :css, 'a.lbAction' ).first.click

    expected_list  = Customer.active.first.tasks.active.all
    expected_count = expected_list.count
    actual_list    = find( '#timesheet_task_ids_text' ).value.split( "\n" )

    assert_equal actual_list.count, expected_count, 'Incorrect number of task lines added to the text area'

    # Now add them and make sure it worked.

    find( :xpath, '//input[@name="add_row"]' ).click

    assert_empty find( '#timesheet_task_ids_text' ).value, 'Task list text area has unexpected content'

    expected_list.each do | task |
      assert page.has_content?( task.title ), "Task title '#{ task.title }' not found in page"
    end
  end
end
