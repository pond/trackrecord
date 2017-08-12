# Change log



## Version 3.0.0, 2017-08-11



After an extremely long update hiatus, TrackRecord is finally brought up
to date at least in terms of its infrastructure - Rails 5, Ruby support
up to 2.4.x and all updated gems throughout.

- Rails 5, Ruby 2.4.1 validation, full bundle update and legacy removal.

- PostgreSQL 9.6 used for testing, but there's little in the way of
  special or heavy SQL that should prevent other engines or older
  PostgreSQL versions from working fine.

- Changed all `.rdoc` files to Markdown, `.md`. If reading any entries in
  the log below, bear that in mind where filename references are given.

- No need to edit any `secret_token.rb` file now, but if you run in
  Development mode routinely, then please *do* change the value assigned
  in `config/secrets.yml` to something only you know. Do not check it in
  to source control systems. Command `rake secret` will generate a new
  random value for you to substitute. It's a better idea, though, to run
  in Production mode and use environment variable `SECRET_KEY_BASE` to
  convey that data.



## Version 2.31, 2014-05-25



This version has been updated to include Ruby 2.1.2 in the Gemfile, which
is a pretty big change for a minor version number :-) but it'll run fine
on 1.9.3 or later, as with previous releases. Edit the line near the top
of "Gemfile" to specify your preferred Ruby version if need be.

Please see "README.rdoc" for information on installation and upgrades.
If updating, run bundle install" after updating your sources then migrate
your data with "rake db:migrate"; Rails 3.2.18 is required by this update
as it include important security fixes.

Otherwise, this is a minor bug fix release, fixing the following:

- JavaScript presence detection failed when using username/password
  sign-in.

- The no-JavaScript version of the timesheet editor's "Add tasks to
  timesheet" feature didn't work.

Additional test coverage is included to catch the faults including new
use of Poltergeist/PhantomJS to run automated integrated tests over parts
of the user interface that use JavaScript. As ever, there is far more
work to do here, but it's a good start.



## Version 2.30, 2014-04-04



Please see "README.rdoc" for information on installation and upgrades.
If updating, run bundle install" after updating your sources then migrate
your data with "rake db:migrate".

A while ago, a major OpenID provider shut down its ID service. Although
other providers still exist - e.g. Google account holders have an OpenID,
even if they don't realise it - OpenID has struggled to gain widespread
adoption and finding an easy-to-use provider with a clear indication of
your actual ID can be a struggle.

Accordingly, TrackRecord now offers a more traditional sign-in option
based on e-mail address and password. For administrators, the process is:

- At first-time startup of a new installation, you get to choose either
  an OpenID for your new admin account, or provide an e-mail address and
  password which is used for subsequent sign-in, or you can even provide
  both and use either to sign in later.

- When someone new needs to use the system, the administrator creates
  their user account as normal. Either that user tells the admin what
  OpenID they want, or the admin assigns a temporary password to the
  new account, or both; the admin then tells the new user about the
  password (if that's been chosen). When the user signs in, they'll be
  asked to reset the temporary password to a permanent one that only
  they know. Adminstrators can actually change this - though it isn't
  recommended - by deselecting the "must change password on sign-in"
  option when creating the new user account. Administrators can also
  re-set this option for existing users should they need to re-issue a
  password (maybe the user forgot theirs), or should they want the user
  to choose another password.

- From the normal user perspective, the user can sign in with their OpenID
  if they gave one to the administrator, and/or their e-mail address and
  password. As per the above, they may be asked to change that the first
  time they sign in, or if the administrator had subsequently turned back
  on the "must change password" flag on their account.

In TrackRecord, the process is always one wherein the administrator creates
accounts for new users. Accordingly, the usual process of password reset
messages, "forgotten my password" systems and so-on are not provided; a
user who had forgotten their access details would contact the administrator
who could issue a new temporary password by editing the user's account. The
control over access management is primarily in the hands of the admin, not
all other users of the system.

Security is provided via rails-bcrypt and uses salted, encrypted storage.
This is fairly secure; if you are unfortunate enough to have your database
compromised and its contents downloaded by a miscreant, they are unlikely
to be able to determine the unencrypted value of any password. It would
still be necessary to inform all users of such a breach so they could make
informed decisions about what to do with other web sites should they have
used the same password anywhere else.

- https://github.com/codahale/bcrypt-ruby/tree/master

If you are unsure about detection of, mitigation of, or handling of
security breaches when running a server, please spend some time Googling
around the issue so that you can have confidence your provided service.


### Other notable changes

- The sign-in/sign-up process has been cleaned up with some dead code
  removal, bug fixes in e-mail sending, lots of improvements in User
  model validation and so-on. Basically, a general overhaul.

- Removal of some unncessary configuration items, related to continued
  extension of internationalisation through "config/locales...", though
  a great deal of work is still to be done here with many hard-coded
  strings throughout the application.

- Improved indication of errant fields in forms.

- Fewer places where links might accidentally be shown to users that
  lead to a "not authorised" response.



## Version 2.26, 2014-03-20



Please see "README.rdoc" for vital information on installation, upgrading
from an earlier version, database requirements and how to run the built in
test suite that helps verify your database's suitability for TrackRecord.

This release is a small update that adds a convenience feature to create
a new first task for a project, at the same time a project is made. A
similar extension has been added when creating customers too; a new first
project can be made at the same time. This is intentionally a simple
feature that only requires a task or project title and uses default
values for the rest of the item, which you can edit later if necessary.

Other maintenance related changes:

- This release uses the new "Gemified" Safe In Place Editor code, now
  available on RubyGems. You must run "bundle install" if you've upgraded
  from an earlier release. Due to important security patches, Rails 3.2.17
  is also required. The PG gem for PostgreSQL users needs to be at 0.17.1
  or later. Gemfile requrements for "calendar_date_select" were inaccurate
  and have been fixed and a general "gem update" will mean that several
  other updated gems will be included.

- Integration tests are being added using Capybara, a gem which has some
  quite heavyweight dependencies, including Nokogiri. This may be time
  consuming or troublesome to install when you do "bundle install" or
  "bundle update". If you want to avoid this and either not run tests or
  skip the integration tests, comment out the "gem 'capybara'" line in
  the "Gemfile" file before you run "bundle install" or "bundle update".

  A test mode bypass of OpenID authentication has been added for
  integration test purposes. It's only active in test mode.

  See the README.rdoc file for more information on installing Nokogiri,
  especially if you get warnings at run-time about LibXML versions.

- The ORGANISATION_NAME configuration constant has been removed; locale
  files are now exclusively used for this, rather than half-and-half.

- The layout of the confirmation view used when deleting projects has
  been improved a little.

- There was a small bug fix in the Timesheet class that might cause a
  long running server (two years or more with no restarts) to begin to
  reject new timesheets as out-of-year-range. A related test failed once
  the current year rolled over to 2014; the Timesheet class computed the
  allowed range statically at startup, taking "this year +/- 2", rather
  than calculating it dynamically at each new timesheet save or update,
  thus taking account of new accumulating data in the work packets.

- Duplicated locale data for the Will Paginate gem has been resolved in
  the locale files.

- Documentation has been updated with better generation incorporating
  both README.rdoc and renamed-for-GitHub doc/README_FOR_APP.rdoc in a
  way that prevents broken links within "doc/app/index.html". This
  also-renamed CHANGELOG.rdoc file is also included. Finally, titles are
  now correct - no more "YOUR_TITLE" text!



## Version 2.25, 2013-11-29



Please see "README.rdoc" for vital information on installation, upgrading
from an earlier version, database requirements and how to run the built in
test suite that helps verify your database's suitability for TrackRecord.

Version 2.25 uses the new "Gemified" Safe In Place Editor code, now
available on RubyGems. It's important to run "bundle install" if you have
upgraded. Rails 3.2.15 is also required.



## Version 2.24, 2013-10-16



Please see "README.rdoc" for vital information on installation, upgrading
from an earlier version, database requirements and how to run the built in
test suite that helps verify your database's suitability for TrackRecord.

Version 2.24 introduces the following new features:

- Easier to access report modification as requested by Issue #24,
  requested by sarev.

Version 2.24 fixes the following bugs that were found in v2.23:

- The bulk timesheet commit form would raise an error under
  certain date conditions.

- An in-place title editing issue arising from an incompatibility
  between Rails and Prototype.js 1.7's more strict adherence to
  HTTP rules on data encoding has been worked around within the
  Safe In Place Editor plugin. This fixes Issue #21, reported by
  sarev (with thanks).

- Saved report shared flags and copying didn't work as expected
  for various user types; essentially the feature was only half
  implemented. Now done properly!

- In-place editors for saved report titles and share flags are
  now supported in the index view.

There are also various efficiency improvements and areas of code tidying.



## Version 2.23, 2013-09-09



Please see version 2.20's change information below for important
notes about database requirements.

Version 2.23 fixes the following bugs that were found in v2.22:

- Fixes Issue #22, reported by Arpel (with thanks).

- Fixes billable/non-billable radio selection in report generator
  (the reported flag value was the opposite of that intended).



## Version 2.22, 2013-09-05



Please see version 2.20's change information below for details. In
particular, please check the database/PostgreSQL notes therein.

Version 2.22 fixes the following bugs that were found in v2.21:

- Manager-type users couldn't edit their profile details due to a
  typing error ("@f" instead of just "f").



## Version 2.21, 2013-08-19



Please see version 2.20's change information below for details. In
particular, please check the database/PostgreSQL notes therein.

Version 2.21 fixes the following bugs that were found in v2.20:

- Fixed a helper call-through usage bug in ReportsController that
  showed up in a live deployment. With every new release,
  https://github.com/pond/trackrecord/issues/6 becomes more urgent.

- Satisfactory reports performance in that context, thus reduced
  production application log level down to normal (not really a bug
  so much as an in-passing note!).



## Version 2.20, 2013-08-16



Please see the version 2.11 change details later in this file for very
important details about upgrading from an earlier version or installing
anew. If you're already running version 2.11, there are few extra steps
to take - just update your TrackRecord files with the new release. You
then need to run "bundle install" to get updated required gems.

THIS RELEASE WORKS BEST ON POSTGRESQL. If you are using another
database, please see the HTML documentation in "doc/app/index.html" for
details about other database configurations. TrackRecord should work on
other databases, but report performance will be poor.

Version 2.20 fixes the following bugs that were found in v2.11:

- The report generator was often slower than v2.04, which it was supposed
  to improve upon. The new report generator is much faster than both in
  all circumstances.

  The TrackRecordReport API HAS NECESSARILY CHANGED AS A RESULT - just
  after I'd said it would be stable for report generators...! Hopefully
  the v2.10/v2.11 series were sufficiently short lived that nobody wrote
  code against that API. There was no other way to improve performance.

  The TrackRecordSection API has changed too. See "doc/app/index.html"
  for API documentation.

  This complete rewrite of the report engine leads to the version number
  bump to v2.20. There are no database changes or migrations, so if you
  are nervous about the changes, you can always roll back the
  TrackRecord files via e.g. Git.

- The "copy report" feature now actually copies reports (!).

- The list of saved reports uses the correct user ID for URLs in the view
  (a technical level fix that users shouldn't notice much).

The only user-facing enhancements are the performance improvements
described above.



## Version 2.11, 2013-08-05



The procedure to upgrade from any v2.x release or to install anew is the
same, though upgraders may already have completed some steps:

- INSTALLING:
  If you are not using 'rvm' to manage your Ruby environment, I strongly
  recommend getting that set up, though it's not essential. See:

    https://rvm.io

- INSTALLING:
  If you haven't already, copy "config/database_blank.yml" as
  "config/database.yml" and fill in the details for your database.
  TrackRecord is tested on PostgreSQL 8 though others should work too.

    http://www.postgresql.org

- FOR UPGRADING OR INSTALLING v2.11:
  Update config/production.rb with a path prefix if necessary. This step
  is required because of a very long standing Rails bug.

  See the comments above the "config.relative_url_root" line for details.
  This is vital for anyone running TrackRecord in a non-root location,
  even if you use something like Phusion Passenger and normally expect
  to need no such configuration changes.

    https://www.phusionpassenger.com

- FOR UPGRADING OR INSTALLING v2.11:
  Set up, or update your gem bundle, make sure your database is up to
  date and make sure all the static assets (stylesheets etc.) are
  precompiled fully:

    bundle install
    RAILS_ENV=production rake db:migrate
    RAILS_ENV=production rake assets:clean
    RAILS_ENV=production bundle exec rake assets:precompile

Please do all of the upgrade steps if running any version 2 release prior
to v2.11. If upgrading from version 1, please see the version 2.00 change
log details towards the end of this file.

Version 2.11 of TrackRecord fixes issues with the asset pipeline
migration introduced in version 2.10 and clears up documentation to make
installing and upgrading easier. There are no other changes or fixes.



## Version 2.10, 2013-08-02



Please see the version 2.00 notes later for information about updating
from version 1. You will need to migrate your data to upgrade from any
previous v2.x release; for example, to migrate the production database,
run this command:

  RAILS_ENV=production rake db:migrate

Use of the Rails asset pipeline and updated gems, including Rails 3.2.14,
mean you will also need to update your Gem bundle and precompile assets
for production:

  bundle install
  RAILS_ENV=production bundle exec rake assets:precompile

This can be a fraught process and the best I can do is recommend you do
web searches for any of the huge range of problems this process seems
prone to throwing up; but with luck, it'll just work. IMPORTANT: If you
run the application from a subdirectory rather than the root of your
domain, even if it's done transparently with Passenger, you have to take
extra steps. See after the change details below for more.

Version 2.10 fixes the following bugs that were found in v2.04:

- Errors made in a timesheet editor grid (e.g. non-numerical hours) would
  cause validation to fail correctly, but changes made elsewhere would be
  reset when the form was presented back with errors listed. Changes to
  the timesheet's week, description and/or commit flag are now maintained.

- Sign-in page updated with new text, fixing outdated links.

- A few minor comment typing errors fixed, some HTML validation fixes,
  further improvements to internationalisation.

- The prototype.js library version is updated to version 1.7.1 (with a
  very large number of alterations despite the minor version change).

- Moved to using the Rails 3 asset pipeline and fixed up issue related to
  this in various plugins. This is a relatively significant change to the
  internal organisation of the software and is the main reason for the
  TrackRecord version number jump.

There are the following enhancements:

- Added "relative week" and "relative month" report ranges. You can
  now for example set a report to work for "last month" and whenever
  it is generated, an appropriate time range is chosen. To support
  this and additional new options, the report editor page has been
  redesigned, hopefully making it easier and faster to use.

- Added a comprehensive report type. This is similar to the by-task
  standard report, but adds user breakdowns showing the contribution of
  selected users to the total hours for each task at each column of the
  report. This is in addition to the by-task and user summary reports.

- Saved reports can now be copied, thus acting as report templates.

- Extensible report generator mechanism. CSV export now runs as a plugin,
  allowing other report manipulation and export mechanisms to be added
  easily by third parties.

- Inline project creation for bulk task import - users reported often
  going through the import process only to realise that they hadn't added
  a project to contain the new tasks. Now both can be done simultaneously.

- Administrators can now bulk-commit timesheets over a given date range.

- Efficiency improvements by using ActiveRecord::Relation better, avoiding
  loading objects into RAM where possible, doing more in the database and
  less inside Ruby code.


### Deploying in a subdirectory

Rails asset precompilation is somewhat broken in that it doesn't understand
applications deployed into subdirectories. If you are not using Heroku, you
can fix this by adding the following into config/environments/production.rb:

  config.assets.initialize_on_precompile = true
  config.relative_url_root = '/<your-app-subdir>'

...then precompile the assets. If already compiled, delete the folder
'public/assets' then precompile again (see earlier for the command).

On Heroku, the 'initialize' flag must be 'false'. The following link may
provide some insight about what to do:

  https://github.com/rails/rails/issues/8941

I apologise for the inconvenience, but I can't do much about a bug like
this that's been in Rails for at least two years, especially now that (at
the time of writing) Rails 4 is out so a Rails 3 fix is even more unlikely.



## Version 2.04, 2013-07-11



Please see the version 2.00 notes later for information about updating from
version 1. If upgrading from an earlier version 2, you will need to migrate
your data; for example, to migrate the production database, run this
command:

  RAILS_ENV=production rake db:migrate

Version 2.04 fixes the following bugs that were found in v2.03:

- Sometimes sorting a timesheet's rows would not fully sort them - you would
  have to sort a second time to get the correct result.

- Reordered timesheet rows were not maintained when the timesheet was saved
  and used as a template for another week; the row order would be reset.

There are the following enhancements:

- Timesheets can now be set to auto-sort their contents when rows are
  added or removed.

- Report titles, if set, are included in all report output for easier
  identification.



## Version 2.02 and 2.03, 2013-04-25



Please see the version 2.00 notes later for information about updating from
earlier versions.

Version 2.02 fixes the following bugs that were found in v2.01:

- Saved reports can now be deleted. Related code tidied up in a few other
  places too.

Version 2.03 fixes the following bugs that were found in v2.02 on a live
deployment, rather than with test data only:

- Sometimes duplicating a timesheet would keep apparently duplicating one
  or more of its rows more than once. This was actually due to an
  iterator removing a new timesheet's default rows, as specified in the
  user's control panel, failing to actually iterate over all objects. It
  seems an explicit call to "all" is required on associated collections
  before "each" to reliably iterate across all objects (!). A lot of
  other files have been updated as a precaution, following the same
  pattern.

- In passing while testing this fix, noticed that attribute protection
  code in the Project model was nonsense (copy and paste error); also,
  the custom initializer override parameters at creation, which were
  only subsequently correctable by editing the instance. This fault was
  replicated in Task, Project, User and Customer models; fixed in all.



## Version 2.01, 2013-04-09



Please see the version 2.00 notes later for information about updating from
earlier version.

This release fixes the following bugs that were found in v2.00:

- Rails 3 converts dates to dates-with-time-and-timezone using the server's
  local timezone rather than UTC as in Rails 2. This could lead to work
  packets and timesheets having incorrect cached date-time values. Editing
  timesheets would show no issues but reports might be wrong. Noticed on
  the Endurance installation when the server automatically changed from
  UTC to UTC+1 on April 1st. Fixed.

- Administrator users were unable to show saved reports from other users
  unless they were shared, even though they could edit them. Administrators
  can now see all reports.

- Date-based searching in "Manage Timesheets" was broken. Now fixed.



## Version 2.00, 2013-03-27



### Important

TrackRecord now requires Rails 3.2. It does not run on Rails 2. As a result,
the Ruby version requirements are increased too; you need version 1.9.3 at
patch 392 or later. The upgrade instructions below assume that this is
already available.

On the client side, TrackRecord's views now assume a competent HTML 5, CSS 2
capable browser is used. It looks best on modern CSS 3 aware browsers such as
recent Safari, Chrome, Opera and Firefox builds. JavaScript is very strongly
recommended but not required, so if you have it turned off in your browser
for any reason or your browser doesn't support it, TrackRecord can still be
used. Internet Explorer is untested and not officially supported at any
version, though it may work in practice.


### Upgrading

To upgrade, first do a full database backup in case anything goes wrong!
Next, unpack TrackRecord somewhere new - don't copy it on top of an existing
installation. Make any configuration changes you made to your old copy:

- You can safely just copy over the old 'config/database.yml'
- ...and 'config/initializers/email_config.rb'
- ...and 'config/initializers/general_config.rb' files

- Possibly port over your e-mail sending configuration for ActionMailer
  in 'config/environments/production.rb' or '...development.rb' - see:
  http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration

You must also set a secret key in 'config/initializers/secret_token.rb';
this is the equivalent of the key that in previous versions lived inside
'config/environment.rb'. Comments in the file give detailed instructions.

The gem dependencies for TrackRecord are all listed in 'Gemfile'. To get
these installed, from inside the 'trackrecord' directory (the same directory
as this change log file and 'Gemfile'), run:

  bundle install

...to make sure all the relevant gems required by the updated TrackRecord
are present. Now make sure your web server is offline and bring your database
up to date (changing 'production' to 'development' if being rightly cautious
and testing on a development copy first):

  rake db:migrate RAILS_ENV=production

Then you should be able to start your web server again. There may be some
server changes needed for Rails 3; consult your web server documentation if
necessary. I recommend using Phusion Passenger, if possible, to serve Rails
application such as TrackRecord.

If you have trouble running 'bundle' or the migration, in the first
instance check Google for the error message you see - upgrading Rails and
using bundles is very rarely a pain-free process and the issues will usually
be to do with your computing environment rather than TrackRecord's own code.


### Changes from version 1.54

See the v1.x branch for more v1.x changes.

- New major version number reflects bump to Rails 3.2 / Ruby 1.9.
  + Functionality is an evolution and refinement over TrackRecord v1.x,
    rather than a major overhaul.

- Improved navigation flow throughout.
  + More consistent and logical navigation options in some places.
  + Updated visual theme makes things easier to read.

- Reports can be saved for recollection and modification later.
  + Can be kept private or shared to other TrackRecord users.
  + Sharing URLs are very simple, since they just refer to a saved.
    database object rather than recording all report parameters.
  + Old-style long report URLs from TrackRecord v1.5 are supported and
    create a temporary user report.
  + Quick report generation buttons available when managing or viewing
    customers, projects, tasks and users.

- All list search forms extended to at long last support date ranges.

- Improved labels for customers, projects and tasks everywhere - link back
  to the original item, with tooltips giving code and description details.

- The beginnings of proper internationalisation are in place, though a lot
  of messages are not yet run through the language files.

- The 'gruff' gem is commented out inside 'Gemfile' to prevent annoying
  dependencies. The graph controller mechanism is still present but will
  not work unless you uncomment the gruff line in 'Gemfile' and re-run
  "bundle install". It isn't used by default anywhere in TrackRecord.

- Bugs related to tasks with no project or projects with on customer fixed.

- Old-style report URLs are now reliable, rather than leading to 404 errors
  on older TrackRecord versions if active tasks had become inactive or vice
  versa. Now the active-vs-inactive lists are reassessed at generation time
  (and the signed in user's task permissions taken into account as usual).
