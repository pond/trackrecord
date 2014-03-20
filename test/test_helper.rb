ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'capybara/rails'

class ActiveSupport::TestCase

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in
  # alphabetical order. The fixtures are large, particularly for report
  # testing, so this is slow.
  #
  # Note: You'll currently still have to declare fixtures explicitly in
  # integration tests -- they do not yet inherit this setting.
  #
  fixtures :all

end

class ActionDispatch::IntegrationTest

  # Make the Capybara DSL available in all integration tests
  #
  include Capybara::DSL

  # Load base fixtures for integration tests, avoiding the huge fixtures for
  # timesheets, work packets and reports. Integration tests covering those
  # areas can add in extra fixtures by calling "fixtures :all".
  #
  fixtures :users, :control_panels,
           :tasks, :projects, :customers,
           :tasks_users, :control_panels_tasks

  # Sign in as a given user (or by default, the admin that's present in
  # the fixtures).
  #
  def thelper_sign_in( id = 'openid.pond.org.uk' )
    visit signin_path
    fill_in :openid_url, with: id
    thelper_submit_with_named_button()
    assert_equal home_path, current_path
  end

  # Assert that a DIV with ID 'errorExplanation' is present on the page, for
  # Rails validation form errors.
  #
  def thelper_assert_has_form_error
    assert page.has_css?('div#errorExplanation')
  end

  # Capybara help - finding elements by "name" attribute does not work as
  # indicated by documentation. We need to use e.g. xpath instead.
  #
  def thelper_find_input_by_name( n = 'commit' )
    find( :xpath, "//input[contains(@name, '#{ n }')]" )
  end
  
  # Submit a form by clicking on an 'input' element with the given name
  # (defaults to 'commit').
  #
  def thelper_submit_with_named_button( n = 'commit' )
    thelper_find_input_by_name( n ).click
  end

end
