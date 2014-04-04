require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 14, User.count, "Wrong user count"
  end

  # =========================================================================
  # =========================================================================

  test "02 make sure user metrics look sane" do
    assert_equal 7, User.active.count,     "Wrong active user count"
    assert_equal 7, User.inactive.count,   "Wrong inactive user count"
    assert_equal 2, User.admins.count,     "Wrong admin-type user count"
    assert_equal 4, User.managers.count,   "Wrong manager-type user count"
    assert_equal 8, User.restricted.count, "Wrong normal-type user count"

    assert_equal 46, User.admins.first.saved_reports.count,     "Expected first admin user to have 46 reports"
    assert_equal  2, User.managers.first.saved_reports.count,   "Expected first manager user to have 2 reports"
    assert_equal  0, User.restricted.first.saved_reports.count, "Expected first restricted user to have no reports"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "03 basic model paranoia" do
    u = User.new
    refute_nil u.code, "New user has no assigned code"
    assert_equal User::USER_TYPE_NORMAL, u.user_type, "New user has unexpected user type"
    refute u.save, "A blank user was saved"

    u.name         = "Foo User"
    u.email        = "foo@test.com"
    u.user_type    = User::USER_TYPE_ADMIN

    refute u.save, "A new user without an identity URL was saved"

    u.identity_url = User.first.identity_url
    refute u.save, "A new user with a non-unique identity URL was saved"

    u.identity_url += ".com"
    assert u.save, "A valid pre-authorisation user could not be saved"

    u.reload
    refute_nil u.control_panel, "A new user did not get assigned a Control Panel instance"
    assert u.timesheets.try( :empty? ), "A new user has unexpected nil, or associated timesheets"
    assert u.tasks.try( :empty? ), "A new user has unexpected nil, or associated tasks"

    u.name = "Test user new"
    u.email = nil
    refute u.save, "An updated user with only a name was saved"

    u.name = nil
    u.email = "test_new@test.invalid"
    refute u.save, "An updated user with only an e-mail address was saved"

    u.name = "Test user new"
    u.email = User.first.email
    refute u.save, "An updated user with a non-unique e-mail address was saved"

    u.email = "not an address" # I know, not exhaustive! Just top-level validation paranoia.
    refute u.save, "An updated user with an invalid e-mail address was saved"

    u.email = "test_new@test.invalid"
    assert u.save, "A valid user update was refused"

    u.user_type = "invalid"
    refute u.save, "An updated user was saved with an invalid user type"

    u.user_type = User::USER_TYPE_ADMIN
    assert u.save, "A valid fully defined user could not be saved"

    u.tasks = Task.active[1..5]
    assert u.save, "A valid update to assign active tasks to a user was refused"

    u.tasks = [ Task.inactive.first ]
    refute u.save, "An invalid update to assign inactive tasks to a user was allowed"

    r = SavedReport.new
    r.user = u
    r.save!
    rid = r.id
    cpct = ControlPanel.count

    uid = u.id
    u.destroy
    assert_raises ActiveRecord::RecordNotFound, "A deleted user was found by ID" do
      User.find( uid )
    end

    assert_equal cpct - 1, ControlPanel.count, "Control panel count did not decrease by 1 when a user was destroyed"
    assert_raises ActiveRecord::RecordNotFound, "A report was found by ID after its owner was deleted" do
      SavedReport.find( rid )
    end
  end

  # =========================================================================
  # Check that active/inactive task assignments work for users of different
  # types within the fixture data set.
  # =========================================================================

  test "04 task assignment" do

    # If we don't have the expected number of admins, managers and normal
    # users, the rest of the tests may not work on the object they expect
    # so raise a failure here to prompt a code review of what follows.

    users    = User.where( :user_type => User::USER_TYPE_NORMAL  )
    managers = User.where( :user_type => User::USER_TYPE_MANAGER )
    admins   = User.where( :user_type => User::USER_TYPE_ADMIN   )

    assert_equal  2,   admins.count, "Wrong admin count"
    assert_equal  4, managers.count, "Wrong manager count"
    assert_equal  8,    users.count, "Wrong user count"

    u2 = User.restricted
    m2 = User.managers
    a2 = User.admins

    assert_equal users.all,    u2.all, "Scoped normal user accessor results differ from manually specified conditions"
    assert_equal managers.all, m2.all, "Scoped manager accessor results differ from manually specified conditions"
    assert_equal admins.all,   a2.all, "Scoped admin accessor results differ from manually specified conditions"

    # Note how many of these checks use ".all" to ensure we got an
    # Association back from the User model.

    admin = admins.first # Admin, me, expect all tasks
    assert_equal Task.active.all, admin.active_permitted_tasks.all, "Unexpected admin active task list"
    assert_equal Task.scoped.all, admin.all_permitted_tasks.all, "Unexpected admin task list"

    manager = managers.first
    assert_equal Task.active.all, manager.active_permitted_tasks.all, "Unexpected manager active task list"
    assert_equal Task.scoped.all, manager.all_permitted_tasks.all, "Unexpected manager task list"

    # No user by default has any inactive tasks in their task list,
    # so both active and permitted lists should be the same. We use
    # a user with a known ID and task list from the fixture data.

    user              = User.find( 14 )
    expected_task_ids = [ 135, 101, 357, 88, 230 ]
    expected_tasks    = Task.where( :id => expected_task_ids )

    assert_equal 5,                      user.tasks.count,   "Unexpected normal type user permitted task count"
    assert_equal expected_task_ids.sort, user.task_ids.sort, "Unexpected normal type user permitted task IDs"
    assert_equal expected_tasks.sort,    user.tasks.sort,    "Unexpected normal type user permitted task list"

    user.tasks.each do | task |
      assert task.active, "User-list tasks should all be active"
    end

    # Now change a task and re-test.

    task = expected_tasks.first
    task.active = false
    task.save!

    active_task_ids = expected_task_ids - [ task.id ]
    active_tasks    = Task.where( :id => active_task_ids )

    refute_equal active_tasks.all, expected_tasks.all, "Tasks did not behave as expected while testing users"

    assert_equal active_tasks.all, user.active_permitted_tasks.all, "Unexpected user active task list (2)"
    assert_equal expected_tasks.all, user.all_permitted_tasks.all, "Unexpected user task list (2)"

    # Update the user and re-test.

    user.remove_inactive_tasks
    assert user.save, "Couldn't save updated user after task list modification"

    assert_equal active_tasks.all, user.active_permitted_tasks.all, "Unexpected user active task list (3)"
    assert_equal active_tasks.all, user.all_permitted_tasks.all, "Unexpected user task list (3)"

    # Update the task. Since the user was changed, its task list
    # should not alter either.

    task.active = true
    task.save!

    refute_equal expected_tasks.all, user.active_permitted_tasks.all, "Unexpected user active task list (4)"
    refute_equal expected_tasks.all, user.all_permitted_tasks.all, "Unexpected user task list (4)"
  end

  # =========================================================================
  # =========================================================================

  test "05 user type flag-based methods" do
    user    = User.where( :user_type => User::USER_TYPE_NORMAL  ).first
    manager = User.where( :user_type => User::USER_TYPE_MANAGER ).first
    admin   = User.where( :user_type => User::USER_TYPE_ADMIN   ).first

    assert user.restricted?,    "Normal user has wrong 'restricted?' result"
    refute user.privileged?,    "Normal user has wrong 'privileged?' result"
    refute user.manager?,       "Normal user has wrong 'manager?' result"
    refute user.admin?,         "Normal user has wrong 'admin?' result"

    refute manager.restricted?, "Manager has wrong 'restricted?' result"
    assert manager.privileged?, "Manager has wrong 'privileged?' result"
    assert manager.manager?,    "Manager has wrong 'manager?' result"
    refute manager.admin?,      "Manager has wrong 'admin?' result"

    refute admin.restricted?,   "Admin has wrong 'restricted?' result"
    assert admin.privileged?,   "Admin has wrong 'privileged?' result"
    assert admin.manager?,      "Admin has wrong 'manager?' result" # (sic.) admins have manager privileges
    assert admin.admin?,        "Admin has wrong 'admin?' result"
  end

  # =========================================================================
  # =========================================================================

  test "06 identity URL rationalisation" do

    assert_equal "http://foo.pond.org.uk",  User.rationalise_id( "http://foo.pond.org.uk"   ), "Identity URL rationalisation failure"
    assert_equal "http://foo.pond.org.uk",  User.rationalise_id( "foo.pond.org.uk"          ), "Identity URL rationalisation failure"
    assert_equal "http://foo.pond.org.uk",  User.rationalise_id( "http://foo.pond.org.uk/"  ), "Identity URL rationalisation failure"
    assert_equal "http://foo.pond.org.uk",  User.rationalise_id( "foo.pond.org.uk/"         ), "Identity URL rationalisation failure"
    assert_equal "https://foo.pond.org.uk", User.rationalise_id( "https://foo.pond.org.uk"  ), "Identity URL rationalisation failure"
    assert_equal "https://foo.pond.org.uk", User.rationalise_id( "https://foo.pond.org.uk/" ), "Identity URL rationalisation failure"

    u              = User.new
    u.name         = "Foo User"
    u.email        = "foo@test.com"
    u.identity_url = "foo.pond.org.uk"
    u.save!

    assert_equal "http://foo.pond.org.uk", u.identity_url, "User identity URL not rationalised upon saving"
  end

  # =========================================================================
  # =========================================================================

  test "07 password rules" do
    u       = User.new
    u.name  = "Foo User"
    u.email = "foo@test.com"

    refute u.save, "A user with no OpenID or password was saved"
    assert_equal I18n.t( :'activerecord.errors.models.user.attributes.identity_url_or_password.either' ), u.errors.messages[ :base ].first

    # Incorrect confirmation; note nil confirmation *is* permitted in model,
    # i.e. a nil value for confirmation results in a validation *pass*, but an
    # empty string does not; forms in views typically ensure an empty string.
    #
    # http://api.rubyonrails.org/classes/ActiveModel/Validations/HelperMethods.html#method-i-validates_confirmation_of

    u.password = "foobly"
    u.password_confirmation = "barbly"

    refute u.save, "A user with incorrect password confirmation was saved"
    assert u.errors.messages.has_key?( :password ), "Expected error message on 'password' attribtue is missing"

    # Too short.

    u.password = "foo"
    u.password_confirmation = u.password # (cough)

    refute u.save, "A user with too short a password was saved"
    assert u.errors.messages.has_key?( :password ), "Expected error message on 'password' attribtue is missing"

    # http://xkcd.com/936/

    u.password = "correct horse battery staple"
    u.password_confirmation = u.password

    assert u.save, "A valid user could not be saved"
  end
end
