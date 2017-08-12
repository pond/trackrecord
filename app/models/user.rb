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

  require 'bcrypt'

  audited( {
    :except => [
      :lock_version,
      :updated_at,
      :created_at,
      :id,
      :last_committed
    ]
  } )

  DEFAULT_SORT_COLUMN    = 'name'
  DEFAULT_SORT_DIRECTION = :asc
  DEFAULT_SORT_ORDER     = { DEFAULT_SORT_COLUMN => DEFAULT_SORT_DIRECTION }

  USED_RANGE_COLUMN      = 'created_at' # For Rangeable base class

  default_scope( -> { order( DEFAULT_SORT_ORDER ) } )

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

  # Attach a ControlPanel object to this User whenever one is created.

  before_create( :add_control_panel )

  # A user account has an optional secure password. This runs through BCrypt
  # behind the scenes. We don't use Rails 3's "has_secure_password" because
  # our model has unusual requirements and there are naming issues with the
  # BCrypt gem, which decided to rename itself at version 3.2.13, but Rails
  # at the time of writing still requires the old named version, which would
  # force us to use an outdated gem.
  #
  # Instead, code in 'activemodel-3.2.17/lib/active_model/secure_password.rb'
  # is adapted here, where required
  # http://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password
  # https://github.com/codahale/bcrypt-ruby/tree/master
  #
  # These accessors are for local use when forms are trying to change data.
  # Validations later add additional related accessors. Do not use the
  # "password" attribute to see if there's a password on an existing model;
  # use "has_validated_password?" insead.

  attr_accessor :password, :new_password, :old_password

  # A user account always needs a type, unique e-mail address and human name.
  # Identity URLs, where provided, must be unique; either a URL or a password
  # must be present.

  validates_presence_of( :name )

  validates(
    :email,
    :uniqueness => true,
    :format     => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }
  )

  validates(
    :identity_url,
    :allow_blank => true,
    :uniqueness  => true
  )

  validate( :identity_url_or_password )

  # When a user is saved, all associated tasks must be active, else the list
  # needs to be updated.
  #
  validate( :tasks_are_active )

  # No I18n messages for these, since it's difficult to get the custom list
  # of types and this should never happen in production anyway. It's really
  # just for debugging.
  #
  # For the true/false check, "..._presence_of" triggers for 'false', but all
  # we want is "not nil". That's why "..._inclusion_of" is used.

  validates_inclusion_of(
    :user_type,
    :in      => [ USER_TYPE_ADMIN, USER_TYPE_MANAGER, USER_TYPE_NORMAL ],
    :message => "must be one of '#{ USER_TYPE_ADMIN }', '#{ USER_TYPE_MANAGER }' or '#{ USER_TYPE_NORMAL }'"
  )

  validates_inclusion_of(
    :active,
    :in => [ true, false ],
    :message => "must be set to 'true' or 'false'"
  )

  # Password rules are a bit complex, because of the whole "user can set a
  # password where there is none, so there's no old password to provide"
  # thing, the "user can change a password, providing the old one" thing and
  # the "user can clear their password, providing the old one and no new one"
  # conditions.
  #
  # The model assumes that forms use "password" / "password_confirmation" only
  # if no password is present; else "old_password", "new_password" and
  # "new_password_confirmation" must be used.
  #
  # First:
  #
  # We only look at password and password confirmation if the digest is nil,
  # indicating no current password.
  #
  # In that case, if both are blank, do nothing; else validate password and
  # that it matches confirmation.
  #
  # Before saving, same conditions apply; set digest only if digest is nil,
  # but password is not.

  validates(
    :password,
    :allow_blank  => false,
    :confirmation => true, # (Adds accessors for "password_confirmation...")
    :length       => { :minimum => 4 },
    :if           => ->( user ) {
      ( not user.has_validated_password? ) and (
        user.password.present? or user.password_confirmation.present?
      )
    }
  )

  # Next:
  #
  # We only look at old password, new & new confirmation if digest is non-nil,
  # indicating a current password that might need changing.
  #
  # In this case, if new password or new confirmation are not blank, then they
  # must match, new password must be valid, old password must be correct.
  #
  # If old password is not blank but new & confirmation are, then this is an
  # attempt to clear the existing password; old must match. A catch here - what
  # if the user is changing to a blank password (removing it) but also has set
  # no identity URL? The custom validator we use checks that too.
  #
  # If all are blank, no change.

  validates(
    :new_password,
    :allow_blank  => true,
    :confirmation => true, # (Adds accessors for "new_password_confirmation...")
    :length       => { :minimum => 4 },
    :if           => ->( user ) { user.has_validated_password? }
  )

  validate(
    :old_password_is_correct_if_changing,
    :if => ->( user ) { user.has_validated_password? }
  )

  # Finally:
  #
  # Before saving, similar conditions to the validation cases above exist for
  # whether or not we set or clear the password digest field.

  before_save( :set_password_data )

  # Before saving, make sure the Open ID, if present, is sane.

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

  # Returns self if the password is correct, otherwise false. Taken from
  # 'activemodel-3.2.17/lib/active_model/secure_password.rb'.
  #
  def authenticate( unencrypted_password )
    if ( has_validated_password? and BCrypt::Password.new( password_digest ) == unencrypted_password )
      self
    else
      false
    end
  end

  # Did this instance have a valid password set at the time it was loaded
  # from the database? (Note that the "password" attribute MUST NOT be used
  # for that check as most of the time it'll be 'nil'; note also that it is
  # never possible to retrieve the decrypted value of a password from the
  # database's encrypted copy; all we can do is take a user-supplied
  # password, encrypt it and see if the result matches the stored digest).
  #
  # Note that locally setting a password which is not yet persisted in the
  # database (and thus may not yet have been validated) will NOT result in
  # a 'true' response from this method.
  #
  def has_validated_password?

    # There are other ways to do this (e.g. "password_digest?" instead of
    # "!! password_digest") but I felt this was the most legible.

    if ( password_digest_changed? )
      !! password_digest_was
    else
      !! password_digest
    end
  end

  # Ask for the plaintext password - only possible on a user instance where
  # the "password" or "new_password" attribute has been actively *set*. The
  # "password" attribute is returned in favour of "new_password" if they
  # are both present.
  #
  # A new User record from the database will never be able to return this
  # data. It's only for use when you have a new-password / changed-password
  # scenario in an existing instance and need to retrieve the value.
  #
  # Never use this to determine if a validated, in-database password exists
  # for the user. Always use "has_validated_password?" for that instead.
  #
  def plaintext_password

    # Do this rather than "password || new_password" so that an empty
    # string in "password" is *not* returned in favour of something more
    # significant in "new_password".

    password.blank? ? new_password : password
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
    ( self.restricted? ) ? self.tasks.all : Task.all
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

  # Custom validation method.
  #
  def identity_url_or_password
    errors.add(
      :base,
      I18n.t(
        :'activerecord.errors.models.user.attributes.identity_url_or_password.either'
      )
    ) unless ( identity_url.present? or has_validated_password? or password.present? )
  end

  # Custom validation method.
  #
  def tasks_are_active
    self.tasks.all.each do | task |
      errors.add(
        :base,
        I18n.t(
          :'activerecord.errors.models.user.attributes.tasks.inactive',
          :task_title => task.title
        )
      ) unless ( task.active? )
    end
  end

  # Custom validation method.
  #
  def old_password_is_correct_if_changing
    if ( old_password.present? || new_password.present? || new_password_confirmation.present? )
      if ( authenticate( old_password ) )

        # Old password was correct - what if the new password is blank? Do we
        # have an identity URL? The "identity_url_or_password" validator does
        # not catch this edge case.

        errors.add(
          :base,
          I18n.t(
            :'activerecord.errors.models.user.attributes.identity_url_or_password.either'
          )
        ) unless ( identity_url.present? or new_password.present? )
      else
        errors.add(
          :old_password,
          I18n.t(
            :'activerecord.errors.models.user.attributes.old_password.wrong'
          )
        )
      end
    end
  end

  # Run via "before_create".
  #
  def add_control_panel
    unless ( self.control_panel )
      self.control_panel = ControlPanel.new
    end
  end

  # Run via "before_save". Assumes validations have taken care of things
  # like checking an old password is correct, or that a new password matches
  # a confirmation value.
  #
  def set_password_data
    alter = false

    if ( has_validated_password? )

      # A password is currently set. Presence of an old password indicates
      # intention to change digest to a new value (which may be blank).

      if ( old_password.present? )
        value = new_password
        alter = true
      end
    else

      # No password currently set. Presence of password attribute value
      # indicates intention to set digest to that value.

      if ( password.present? )
        value = password
        alter = true
      end
    end

    if ( alter )
      if value.blank?
        self.password_digest = nil
      else
        self.password_digest = BCrypt::Password.create( value )
      end
    end
  end

  # Run via "before_save".
  #
  def rationalise_identity_url
    self.identity_url = User.rationalise_id( identity_url )
  end
end
