ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'capybara/rails'
require 'capybara/poltergeist'

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

  # Set up Poltergeist, which via PhantomJS (which you must have installed -
  # e.g. "brew install phantomjs" if using HomeBrew on OS X) supports headless
  # browser-based testing of page content that includes JavaScript.

  @@ukorgpondtrackrecord_nonjs_driver = Capybara.current_driver

  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(
      app,

      # Must sadly ignore JS errors, as Prototype.js causes on-unload failure
      # "TypeError: 'undefined' is not an object (evaluating 'handler.call')".
      #
      # TODO: Migrate to jQuery at long last and ultimately be able to delete
      #       this entire register_driver block and its js_errors option?
      #
      :js_errors => false
    )
  end

  Capybara.javascript_driver = :poltergeist

  # The use of Poltergeist / PhantomJS means that threading issues cause
  # changes within transactions not to be "seen" by the testing code, so
  # some tests fail (for example, deleting all users, then visiting the
  # signup page to verify that you got the first-time-signup view, would
  # not work). We use Database Cleaner for integration tests to solve this,
  # but only when JavaScript is required. Otherwise, it's cripplingly slow!
  #
  # Call the method below within a test to enable JavaScript. Otherwise, for
  # any integration test, JavaScript is disabled. After each test is run,
  # JavaScript is automatically disabled again.
  #
  # Remember, tests running with JavaScript enabled require Database Cleaner
  # and due to the large data set used for testing, this is extremely slow.
  # Since the delays are at startup/teardown, one mitigation strategy is to
  # simply write as much as possible in a very large single test, but this
  # has obvious drawbacks. Another might be to manually call
  # "thelper_disable_database_cleaner()" after enabling JavaScript, but only
  # if you know that your test makes no local database changes at all - the
  # in-database changes can occur via simulated web page actions only.
  #
  def thelper_enable_javascript_for_this_test
    sleep 2 # Hack, avoids (very) intermittent obscure error from deep inside PostgreSQL adapter at switch over :-(

    Capybara.current_driver = :poltergeist
    thelper_enable_database_cleaner()

    self.class.teardown :thelper_disable_javascript_after_test
  end

  # Sign in as a given user (or by default, the admin that's present in
  # the fixtures). Returns the user for caller convenience.
  #
  def thelper_sign_in( u = User.find_by_identity_url( 'http://openid.pond.org.uk' ) )
    visit signin_path
    fill_in :sign_in_identity_url, :with => u.identity_url
    thelper_submit_with_named_button()
    assert_equal home_path, current_path
    return u
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

private

  # Called via "thelper_enable_javascript_for_this_test()" and a "teardown"
  # hook. Turns off Database Cleaner and selects the non-JS, non-threaded
  # driver for future integration tests.
  #
  # We'd like to properly wait for the other thread to properly finish any and
  # all database transactions, but there's no programmatic interface to access
  # that information (I tried a few monkey patches but didn't get far). Instead
  # we use the nasty hack of simply waiting a couple of seconds, though on slow
  # machines, this may break.
  #
  def thelper_disable_javascript_after_test
    Capybara.current_driver = @@ukorgpondtrackrecord_nonjs_driver
    thelper_disable_database_cleaner()

    sleep 2

    self.class.skip_callback(:teardown, :after, :thelper_disable_javascript_after_test)
  end

  # Enable Database Cleaner, adding setup/teardown callbacks to get it to
  # do its work. Normal transactional fixture test behaviour is disabled.
  #
  def thelper_enable_database_cleaner
    if ( self.use_transactional_fixtures )
      self.use_transactional_fixtures = false

      DatabaseCleaner.strategy = :deletion

      self.class.setup    :thelper_dc_start_wrapper
      self.class.teardown :thelper_dc_clean_wrapper
    end
  end

  # Disable Database Cleaner, removing previous setup/teardown callbacks.
  # Normal transactional fixture test behaviour is restored.
  #
  def thelper_disable_database_cleaner
    unless ( self.use_transactional_fixtures )
      self.use_transactional_fixtures = true

      self.class.skip_callback(:setup,    :before, :thelper_dc_start_wrapper)
      self.class.skip_callback(:teardown, :after,  :thelper_dc_clean_wrapper)
    end
  end

  # Wrap "DatabaseCleaner.start()" so that a setup filter can be created
  # using a simple symbol to refer to here, and thus can be skipped by the
  # same matching symbol.
  #
  def thelper_dc_start_wrapper
    DatabaseCleaner.start()
  end

  # As "thelper_dc_start_wrapper()", but for "DatabaseCleaner.clean()".
  #
  def thelper_dc_clean_wrapper
    DatabaseCleaner.clean()
  end
end
