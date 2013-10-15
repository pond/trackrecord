require File.dirname(__FILE__) + '/../test_helper'

class ControlPanelTest < ActiveSupport::TestCase

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK and metrics look sane" do
    refute_equal 0, User.count, "Should have more than zero users"
    assert_equal User.count, ControlPanel.count, "User count doesn't match control panel count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  #
  # This is also a good place to test some related utility functions.
  # =========================================================================

  test "02 basic model paranoia and some utilities" do

    # Note that User tests cover the association of a control panel with a user
    # and the user-driven interactions related to it.

    c = ControlPanel.new
    assert c.save, "Could not save clean Control Panel (A)"

    tl = [ Task.active.first ] << Task.inactive.first
    c.tasks = tl
    assert c.save, "Could not save task-laden Control Panel"
    assert_equal tl, c.tasks, "Control panel task list differs from expectations"

    c.remove_inactive_tasks
    assert_equal [ Task.active.first ], c.tasks, "Control panel task list was not updated as expected"

    c.destroy
  end

  # =========================================================================
  # =========================================================================

  test "03 preferences" do

    c = ControlPanel.new
    assert c.save, "Could not save clean Control Panel (B)"

    h = { :one => 1, :two => "two", :three_point_five => 3.5, :four => :four }

    c.set_preference( "foo.foo.foo", "Hello foo!" )
    c.set_preference!( "foo.foo.bar", "Hello bar!" )
    c.set_preference( "foo.bar.hash", h )

    assert_equal( "Hello foo!", c.get_preference( "foo.foo.foo"  ), "Preference 'foo.foo.foo' did not get read back correctly" )
    assert_equal( "Hello bar!", c.get_preference( "foo.foo.bar"  ), "Preference 'foo.foo.bar' did not get read back correctly" )
    assert_equal( h,            c.get_preference( "foo.bar.hash" ), "Preference 'foo.bar.hash' did not get read back correctly" )

    assert_equal( { "foo" => "Hello foo!", "bar" => "Hello bar!" }, c.get_preference( "foo.foo" ), "Preference 'foo.foo' did not get read back correctly" )
    assert_equal( { "hash" => h },                                  c.get_preference( "foo.bar" ), "Preference 'foo.bar' did not get read back correctly" )

    assert_equal( { "foo" => { "foo" => "Hello foo!", "bar" => "Hello bar!" }, "bar" => { "hash" => h } }, c.get_preference( "foo" ), "Preference 'foo' did not get read back correctly" )

    assert_equal( { "foo" => { "foo" => { "foo" => "Hello foo!", "bar" => "Hello bar!" }, "bar" => { "hash" => h } } }, c.get_preference( "" ), "Preference '' (root) did not get read back correctly" )

    c.destroy
  end
end
