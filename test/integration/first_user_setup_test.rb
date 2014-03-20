require 'test_helper'

class FirstUserSetupTest < ActionDispatch::IntegrationTest

  test "001 cannot visit arbitrary paths" do
    get new_project_path
    assert_equal 302, status
  end

  test "002 cannot even visit home page" do
    get "/"
    assert_equal 302, status
  end

  test "003 gets asked to sign in" do
    visit "/"
    assert_equal signin_path, current_path
    assert has_field? :openid_url
  end

  test "004 signs in, builds admin account, signs out, signs in with new account" do
    User.delete_all # (sic.)

    visit signin_path
    fill_in :openid_url, with: "openid.pond.org.uk"
    thelper_submit_with_named_button()

    assert_equal 1, User.count
    assert_equal edit_user_path( User.first ), current_path

    fill_in :user_name, with: "Andrew Hodgkinson"
    fill_in :user_email, with: "ahodgkin@rowing.org.uk"
    thelper_submit_with_named_button()

    assert_equal home_path, current_path

    visit signout_path
    visit signin_path
    fill_in :openid_url, with: "openid.pond.org.uk"
    thelper_submit_with_named_button()

    assert_equal home_path, current_path
  end

  test "005 fixture-defined user signs in" do
    visit signin_path
    fill_in :openid_url, with: "openid.pond.org.uk"
    thelper_submit_with_named_button()
    assert_equal home_path, current_path
  end
end
