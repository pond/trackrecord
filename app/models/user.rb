########################################################################
# File::    user.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Describe the behaviour of User objects. See below for
#           more details.
# ----------------------------------------------------------------------
#           03-Jan-2008 (ADH): Created.
########################################################################

class User < Rangeable

  audited( :except => [
    :lock_version,
    :updated_at,
    :created_at,
    :id,
    :last_committed
  ] )

  DEFAULT_SORT_COLUMN    = 'name'
  DEFAULT_SORT_DIRECTION = 'ASC'
  DEFAULT_SORT_ORDER     = "#{ DEFAULT_SORT_COLUMN } #{ DEFAULT_SORT_DIRECTION }"

  USED_RANGE_COLUMN      = 'created_at' # For Rangeable base class

  default_scope( { :order => DEFAULT_SORT_ORDER } )

  USER_TYPE_ADMIN        = 'Admin'
  USER_TYPE_MANAGER      = 'Manager'
  USER_TYPE_NORMAL       = 'Normal'

  scope :active,     -> { where( :active    => true                    ) }
  scope :inactive,   -> { where( :active    => false                   ) }
  scope :restricted, -> { where( :user_type => User::USER_TYPE_NORMAL  ) }
  scope :managers,   -> { where( :user_type => User::USER_TYPE_MANAGER ) }
  scope :admins,     -> { where( :user_type => User::USER_TYPE_ADMIN   ) }

  # A User object stores information describing a timesheet system
  # user (obviously), including things like name and e-mail address
  # address. It includes a list of Tasks which the user is permitted
  # to see.

  has_one( :control_panel, :dependent => :destroy )

  has_many( :timesheets,    :dependent => :destroy )
  has_many( :saved_reports, :dependent => :destroy )

  has_and_belongs_to_many( :tasks )

  attr_protected(
    :user_type,
    :last_committed,
    :control_panel_id,
    :timesheet_ids,
    :task_ids
  )

  # Make sure the data is sane. Normal users always get created
  # through OpenID setup and the Session Controller, which saves a
  # partially filled in model then gets the user to update the rest.
  # This means that we don't want to validate some things on :save,
  # the default, or the attempt to save the intermediate object will
  # fail. Only validate for :update for such cases.

  validates_presence_of( :name, :email, :on => :update )
  validates_presence_of( :user_type, :identity_url )
  validates_uniqueness_of( :email, :on => :update )
  validates_uniqueness_of( :identity_url )

  validates_format_of(
    :email,
    :on => :update,
    :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  )

  validates_inclusion_of(
    :user_type,
    :in => [ USER_TYPE_ADMIN, USER_TYPE_MANAGER, USER_TYPE_NORMAL ],
    :message => "must be one of '#{ USER_TYPE_ADMIN }', '#{ USER_TYPE_MANAGER }' or '#{ USER_TYPE_NORMAL }'"
  )

  validates_inclusion_of(
    :active,
    :in => [ true, false ],
    :message => "must be set to 'true' or 'false'"
  )

  validate( :tasks_are_active )

  def tasks_are_active
    self.tasks.all.each do | task |
      errors.add( :base, "Cannot assign task '#{ task.title }' to this user - it is no longer active" ) unless task.active
    end
  end

  # Attach a ControlPanel object to this User whenever one is created.

  before_create( :add_control_panel )

  # Before saving, make sure the Open ID is sane.

  before_save( :rationalise_identity_url )

  # Some default properties are dynamic, so assign these here rather than
  # as defaults in a migration.
  #
  # Parameters:
  #
  #   Optional hash used for instance initialisation in the traditional way
  #   for an ActiveRecord subclass.
  #
  #   Optional User object. Default data from a user control panel may be used
  #   for the new object in future, though presently this parameter is ignored.
  #
  def initialize( params = nil, user = nil )
    super( params )

    if ( params.nil? )
      self.code         = "UID%04d" % User.count
      self.active       = true
      self.name         = ''
      self.email        = ''
      self.identity_url = ''
      self.user_type    = User::USER_TYPE_NORMAL
    end
  end

  # Find all tasks which this user is permitted to see; only active
  # tasks are returned. Returns an association-like object on which other
  # methods may be called, e.g. a "find" call, a "count" (for efficient
  # counting of items without needing a special additional count method),
  # and so-on.
  #
  # Call this rather than "user.tasks.active" if you want to retrieve valid
  # task lists even for privileged users, where otherwise there may be no
  # assigned task list (since privileged users can view anything anyway) and
  # "user.tasks" would thus return nothing. Note that the actual assigned
  # task list for privileged users, if any, will be IGNORED by this call.
  #
  def active_permitted_tasks
    ( self.restricted? ) ? self.tasks.active : Task.active
  end

  # As 'permitted_tasks' above, but returns details for both active and
  # inactive tasks.
  #
  def all_permitted_tasks
    ( self.restricted? ) ? self.tasks.scoped : Task.scoped
  end

  # Remove inactive tasks from a user's tasks list. The caller is
  # responsible for saving the updated object.
  #
  def remove_inactive_tasks
    self.tasks = self.tasks.active
  end

  # Is this user restricted? This generally means they can only see
  # anything related to tasks belonging to this user, which only a
  # manager or administrator can assign. See also "privileged?".
  #
  def restricted?
    return ( self.user_type == User::USER_TYPE_NORMAL )
  end

  # Is this user a manager? This generally means elevated privileges
  # but still no full read/write system access for safety. See also
  # "privileged?" - manager accounts are considered privileged.
  #
  # Administrators acquire manager privileges in passing.
  #
  def manager?
    return ( self.user_type == User::USER_TYPE_MANAGER or self.user_type == User::USER_TYPE_ADMIN )
  end

  # Is this user an administrator? This generally means full read/write
  # system access. This does given the potential to completely break
  # the system (e.g. delete a user's control panel but not the user),
  # although steps are taken to try and protect against it. In the end,
  # though, an administrator is assumed to be With Clue.
  #
  # See also "privileged?" and "manager?". Administrators are considered
  # to be both managers and privileged.
  #
  def admin?
    return ( self.user_type == User::USER_TYPE_ADMIN )
  end

  # Is this user *not* restricted? Means the same thing as "manager?" in
  # practice since administrators are also managers, but use of this alias
  # can lead to more legible code.

  alias privileged? manager?

  # Class method - rationalise a URL for use with Open ID by ensuring
  # that the scheme and host are in lower case, the port nubmer is
  # explicit and query or fragment strings are stripped out. Only
  # call for HTTP or HTTPS URLs. If given 'nil', returns 'nil'. If
  # given something with no apparent scheme, assumes 'HTTP'.
  #
  def self.rationalise_id( uri )
    return nil if ( uri.nil? )

    uri      = uri.strip
    original = URI.parse( uri )

    # Did the user omit the 'http' prefix? If so, the URI parser will
    # be a bit confused. Try adding in 'http' instead.

    original = URI.parse( "http://#{uri}" ) if ( original.scheme.nil? )

    # We must by now have at least a scheme and host. If not, something
    # very odd is going on - bail out.

    return uri if ( original.scheme.nil? or original.host.nil? )

    original.path.chomp!( '/' )

    # Looks good - assemble a clean equivalent.

    if ( original.scheme.downcase == 'https' )
      mod = URI::HTTPS
    else
      mod = URI::HTTP
    end

    rational = mod.build( {
      :scheme => original.scheme.downcase,
      :host   => original.host.downcase,
      :port   => original.port,
      :path   => original.path
    } )

    return rational.to_s()

  rescue

    # Catch URI parser exceptions by just bailing out

    return uri
  end

private

  # Run via "before_create".
  #
  def add_control_panel
    unless ( self.control_panel )
      self.control_panel = ControlPanel.new
    end
  end

  # Run via "before_save".
  #
  def rationalise_identity_url
    self.identity_url = User.rationalise_id( identity_url )
  end
end
