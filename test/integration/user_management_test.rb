require 'test_helper'

class UserManagementTest < ActionDispatch::IntegrationTest

  test "001 cannot visit arbitrary paths" do
    get new_project_path
    assert_equal 302, status
  end

  test "002 cannot even visit home page" do
    get "/"
    assert_equal 302, status
  end

  test "003 gets asked to sign in" do
    reset_session!
    visit "/"
    assert_equal signin_path, current_path

    # Fixtures define users, so there should be sign-in stuff excluding the
    # password confirmation for first-time account creation.

    assert has_field? :sign_in_identity_url
    assert has_field? :sign_in_email
    assert has_field? :sign_in_password
    refute has_field? :sign_in_password_confirmation
  end

  test "004 signs in, builds admin account, signs out, signs in with new account" do
    User.delete_all # (sic.)
    visit signin_path

    # With no users defined, the password confirmation field should be present.

    assert has_field? :sign_in_identity_url
    assert has_field? :sign_in_email
    assert has_field? :sign_in_password
    assert has_field? :sign_in_password_confirmation

    fill_in :sign_in_identity_url, with: "openid.pond.org.uk"
    thelper_submit_with_named_button()

    assert_equal 1, User.count
    assert_equal edit_user_path( User.first ), current_path

    fill_in :user_name, with: "Andrew Hodgkinson"
    fill_in :user_email, with: "ahodgkin@rowing.org.uk"
    thelper_submit_with_named_button()

    assert_equal home_path, current_path

    visit signout_path
    visit signin_path
    fill_in :sign_in_identity_url, with: "openid.pond.org.uk"
    thelper_submit_with_named_button()

    assert_equal home_path, current_path
  end

  test "005 fixture-defined user signs in" do
    thelper_sign_in()
  end

  test "006 fixture-defined administrator edits own account" do
    u = User.admins.active.first
    thelper_sign_in( u )
    play_with_password_settings( u )

    # [TODO] Admin-specific settings, if any, for user-type-specific variations in the editor form; skipped to meet 2.30 release, developer tested only
  end

  test "007 administrator edits another account" do
    admin = User.admins.active.first
    other = User.restricted.active.first

    # [TODO] Any of this; skipped to meet 2.30 release, developer tested only
  end

  test "008 manager edits own account" do
    u = User.managers.active.first
    thelper_sign_in( u )
    play_with_password_settings( u )

    # [TODO] Manager-specific settings, if any, for user-type-specific variations in the editor form; skipped to meet 2.30 release, developer tested only
  end

  test "009 manager edits another account" do
    manager = User.managers.active.first
    other = User.restricted.active.first

    # [TODO] Any of this; skipped to meet 2.30 release, developer tested only
  end

  test "010 normal user edits own account" do
    u = User.restricted.active.first
    thelper_sign_in( u )
    play_with_password_settings( u )

    # [TODO] Normal user-specific settings, if any, for user-type-specific variations in the editor form; skipped to meet 2.30 release, developer tested only
  end

  test "011 normal user edits another account" do
    restricted = User.restricted.active.first
    other = User.restricted.active.last

    refute_equal restricted, other, "Different User instances are required for this test"

    thelper_sign_in( restricted )
    visit edit_user_path( other )
    assert_equal 403, status_code
  end

  test "012 deactivated user can't sign in" do
    inactive = User.restricted.inactive.first

    visit signin_path
    fill_in :sign_in_identity_url, with: inactive.id
    thelper_submit_with_named_button()

    # OpenID verification and off-site sign-in happens first, then we end
    # up back at SessionsController checking the ID. If it turns out to be
    # inactive, the 'new' action is rendered from the session path, rather
    # than redirecting to the signin path again (this allows errant data
    # to potentially be preserved across form submissions, giving the user
    # a chance to correct mistakes, hence the pseudo-model "SignIn" class).

    assert_equal session_path, current_path
    page.assert_selector( 'div.flash_error', :count => 1 )
  end

private

  # There are two "edit" links on a home page; one in the navigation bar and
  # one in the body. We need some Capybara dancing to "click" on one. Call here
  # to do it. Pass the User instance for which editing should take place. Does
  # not verify success, in case the whole point is to verify that the signed in
  # user (if any!) is not allowed to do this.
  #
  def visit_account_editor_from_home_page( u )
    first( :link, nil, :href => edit_user_path( u.id ) ).click
  end

  # Run a series of password and identity URL related tests on a user which is
  # initially assumed to have only an identity URL configured on their account.
  # Pass the User object of interest; this user must be signed in.
  #
  # After tests succeed, the user will be unchanged except for "updated_at".
  #
  def play_with_password_settings( u )
    url = u.identity_url

    assert u.identity_url?, "This test requires a User instance with an OpenID"
    refute u.has_validated_password?, "This test requires a User instance with no validated password"

    # First time password setting - no old password / new password fields.
    # Incorrect confirmation.

    visit_account_editor_from_home_page( u )

    fill_in :user_password, with: "right"
    fill_in :user_password_confirmation, with: "wrong"

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 1 )

    # Incorrect, blank confirmation

    fill_in :user_password, with: "right"
    fill_in :user_password_confirmation, with: ""

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 1 )

    # Good data

    fill_in :user_password, with: "right"
    fill_in :user_password_confirmation, with: "right"

    thelper_submit_with_named_button()
    assert_equal home_path, current_path

    assert User.find( u.id ).has_validated_password?

    # Next time password setting - old password / new password fields

    visit_account_editor_from_home_page( u )

    fill_in :user_new_password, with: "nooldoneset"
    fill_in :user_new_password_confirmation, with: "nooldoneset"

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 1 )

    fill_in :user_new_password, with: "nooldoneset"
    fill_in :user_new_password_confirmation, with: "nooldonesetandconfirmationwrong"

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 2 )

    fill_in :user_new_password, with: "!"
    fill_in :user_new_password_confirmation, with: "nooldonesetandconfirmationwrongandtooshort"

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 3 )

    fill_in :user_old_password, with: "oldonewrong"
    fill_in :user_new_password, with: "replacement"
    fill_in :user_new_password_confirmation, with: "replacement"

    thelper_submit_with_named_button()
    page.assert_selector( 'div.errorExplanation li', :count => 1 )

    fill_in :user_old_password, with: "right"
    fill_in :user_new_password, with: "replacement"
    fill_in :user_new_password_confirmation, with: "replacement"

    thelper_submit_with_named_button()
    assert_equal home_path, current_path

    assert User.find( u.id ).has_validated_password?

    # Remove identity URL - should be fine

    visit_account_editor_from_home_page( u )

    fill_in :user_identity_url, with: ""

    thelper_submit_with_named_button()
    assert_equal home_path, current_path

    assert User.find( u.id ).has_validated_password?

    # Remove password (i.e. fill in old, leave new blank) - should fail

    visit_account_editor_from_home_page( u )

    fill_in :user_old_password, with: "replacement"

    thelper_submit_with_named_button()
    assert page.has_content?( I18n.t( :'activerecord.errors.models.user.attributes.identity_url_or_password.either' ) )

    # Add back identity URL, remove password - should be fine

    fill_in :user_identity_url, with: url
    fill_in :user_old_password, with: "replacement"

    thelper_submit_with_named_button()
    assert_equal home_path, current_path

    refute User.find( u.id ).has_validated_password?
  end
end
