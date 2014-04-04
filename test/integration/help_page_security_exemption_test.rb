require 'test_helper'

class HelpPageSecurityExemptionTest < ActionDispatch::IntegrationTest

  test "001 can view sign-in page help while signed out" do
    visit help_path( :sign_in )
    assert_equal help_path( :sign_in ), current_path
  end

  test "002 cannot view another help page while signed out" do
    visit help_path( :xml_import )
    assert_equal signin_path, current_path

    visit help_path( :no_help_will_be_found )
    assert_equal signin_path, current_path
  end

  test "003 can view any valid help page while signed in" do
    thelper_sign_in()
    visit help_path( :xml_import )
    assert_equal help_path( :xml_import ), current_path
  end

  test "004 shows not-found message for invalid help page while signed in" do
    thelper_sign_in()
    visit help_path( :no_help_will_be_found )
    assert_equal 200, status_code
    assert page.has_content?( I18n.t( :'uk.org.pond.trackrecord.controllers.help.view_no_help' ) )
  end
end
