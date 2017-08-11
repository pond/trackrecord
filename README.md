# Welcome to TrackRecord v3.0.0

TrackRecord is a timesheet system written for the Ruby On Rails web
development framework. More information, including a link to the most recent
live source repository, is available at:

* http://trackrecord.pond.org.uk

This software is released under a BSD License. See the LICENSE file
for details along with:

* http://www.opensource.org/licenses/bsd-license.php

Detailed lists of changes in each version are in `CHANGELOG.md`. Technical
documentation can be found via `doc/README_FOR_APP.md`.


## Requirements, new installations and upgrades

### Requirements for all users

TrackRecord was developed upon and is optimised for the PostgreSQL database.
In particular its report generator will run fastest on this platform. Other
Rails-supported databases _should_ work, but only PostgreSQL has been tested
extensively under development. PostgreSQL 8.4 or later should work but is
no longer tested; for the release of version 3.0.0, development was done with
PostgreSQL 9.6.

* http://www.postgresql.org

The installation and upgrade guides below assume you are familiar with the
general procedure for installing Rails applications, with an environment set
up already for Ruby On Rails. If not, then I strong recommend you begin with
"RBEnv", a Ruby version manager:

* https://github.com/rbenv/rbenv

Previously, [RVM](http://rvm.io) was recommended but in more recent years,
RBEnv has become a preferred option - but by all means stick with RVM if it
is working well for you.

Use the version manager to establish a Ruby installation of Ruby 2.2.x,
2.3.x or 2.4.x, with 2.4.x recommended at the time of writing. TrackRecord
will not work on earlier Ruby versions, including not supporting Ruby 2.1.
Select the new Ruby environment (e.g. with `rbenv global 2.4.1`) and
install the Bundler gem (`gem install bundler`).


### Installation for new users

Download either a source archive from the Pond's Place web site (see above),
from GitHub directly, or glone the repository as per GitHub instructions.
Then:

1. Make a secret key

  Edit file `config/initializers/secret_token.rb` as per the instructions in
  the file; comment out the `raise` statement, uncomment the `secret_token`
  assignment underneath and type in or otherwise randomly generate a long
  token string. Running command `rake secret` is a good way to do this.

  _**Never make your modified file public anywhere!**_ Keep it a secret
  always.

2. Configure TrackRecord for your database

  Copy a template database configuration file:

  | Engine         | File                                     |
  |----------------|------------------------------------------|
  | PostgreSQL 8.4 | `config/database_blank.yml`              |
  | SQLite 3       | `config/database_sqlite.yml`             |
  | Others         | Roll your own `config/database.yml` file |

  ...as file `config/database.yml` and modify to suit your database
  configuration. You then need to say what database access gem you want to
  use. Edit file `Gemfile` at the top level of the TrackRecord distribution:

  | Engine     | Change |
  |------------|--------|
  | PostgreSQL | No changes are necessary |
  | SQLite     | Comment out line `gem 'pg', '>= 0.21'` and add line `gem 'sqlite3'` |
  | Others     | Comment out line `gem 'pg', '>= 0.21'` and add whatever `gems` your engine requires |

3. Install dependencies

  Each time you install TrackRecord or an update, check that all required
  dependencies are installed by executing this command:

  ```sh
  bundle install
  ```

  Bundle installation can be a bit fraught. Ruby and Rails gems can be finniky
  things, especially the `nokogiri` gem used during tests or database adapter
  gems. These usually need native components compiling which in turn requires
  a working native compiler and supporting files on your system. If you get an
  error, try doing a web search for it as often the answer can be found there.
  If all else fails see
  [http://trackrecord.pond.org.uk](http://trackrecord.pond.org.uk) for contact
  details.

4. Set up your database

  Issue the following commands to set up all database structures. These
  assume a Unix-like environment. Windows users will need to adapt them.

  ````sh
  bundle exec rake db:create:all
  RAILS_ENV=production  bundle exec rake db:migrate
  RAILS_ENV=development bundle exec rake db:migrate
  ```

  If you get an error, it's likely that your database configuration isn't
  correct - check the steps above are OK.

5. Check it works in development mode

  Depending on where you're deploying, you may have wider web server issues
  to consider. For a local machine, you can test with the Rails built in web
  server:

  * `bundle exec rails s`
  * Visit `http://localhost:3000` in your web browser

  This will test the server in development mode, so changes made here will
  not affect your production environment database unless you configured them
  to be the same in `config/database.yml`.

6. Possibly 'precompile assets' for production mode

  Asset precompilation is rather convoluted Rails-ism aimed at performance
  improvements in production mode. If you run a production server you may
  already be familiar with this and have made your own environment settings
  inside +config/environments/production.rb+, but in any case it is likely
  that you will have to issue this command:

  ```sh
  RAILS_ENV=production bundle exec rake assets:precompile
  ```

  For more, please see the asset pipeline
  [Rails Guide](http://guides.rubyonrails.org/asset_pipeline.html)
  and section "Notes on asset precompilation" below.

7. Running formal tests

  To make sure your database is suitable for TrackRecord, run the tests
  with command `bundle exec rake test`. The tests take a long time to run.
  No back-end failures are expected, but GUI tests cannot run unless you
  also manually install [PhantomJS](http://phantomjs.org).

  If you get warnings about something called Nokogiri and LibXML versions
  at run-time, please see the later section about the Nokogiri gem.

8. Optional configuration

  You may want to look at files `config/initializers/email_config.rb` and
  `config/initializers/general_config.rb` once you've verified that the
  software is running, to see what other things can be changed. In general,
  the other files in `config/initializers` should not be modified.


### Upgrading for existing users

#### Upgrading from version 1.x

If you are updating from a version earlier than v2.0, please see the
`CHANGELOG` file's information about v2.0 for details as this is a major
update from Rails 2 to Rails 3.


#### Upgrading from version 2.00 to 2.11 inclusive

You will need to update `config/production.rb` with a path prefix if you
deploy in a subdirectory rather than you server's document root. This step
is required because of a very long standing Rails bug.

See the comments above the `config.relative_url_root` line for details.
This is vital for anyone running TrackRecord in a non-root location,
_even if you use something like Phusion Passenger and normally expect to
need no such configuration changes._

* [http://www.phusionpassenger.com](http://www.phusionpassenger.com)

You must then also follow the steps shown in the next section.


#### Upgrading for all version 2.00 or later users

Otherwise, whenever you update a version 2.x installation, please do the
following things:

1. Make sure gems are up to date

  (Re-)issue command `bundle install`.

  If you get warnings about something called Nokogiri and LibXML versions
  at run-time, please see the later section about the Nokogiri gem.

2. Make sure your databases are up to date

  Issue the following commands to update all database structures. These
  assume a Unix-like environment. Windows users will need to adapt them.

  ```sh
  RAILS_ENV=production  bundle exec rake db:migrate
  RAILS_ENV=development bundle exec rake db:migrate
  ```

3. Possibly recompile assets for production mode

  TrackRecord as a Rails 3 application requires asset precompilation for
  production mode, unless you changed +config/environments/production.rb+ so
  that this wasn't needed. A new release of TrackRecord means updated assets
  so you need to issue:

  ```sh
  RAILS_ENV=production bundle exec rake assets:clean
  RAILS_ENV=production bundle exec rake assets:precompile
  ```

  For more, please see the asset pipeline
  [Rails Guide](http://guides.rubyonrails.org/asset_pipeline.html)
  and section "Notes on asset precompilation" below.

4. Re-run the formal tests

  To make sure your database is still suitable for TrackRecord, it is
  advisable (though not strictly necessary) to re-run the formal tests with
  the command `rake test`.


### Notes on asset precompilation

#### Deploying in a subdirectory

Rails asset precompilation is somewhat broken in that it doesn't understand
applications deployed into subdirectories. If you are not using Heroku, you
can fix this by adding the following into `config/environments/production.rb`:

```ruby
config.assets.initialize_on_precompile = true
config.relative_url_root = '/<your-app-subdir>'
```

...then precompile the assets. If already compiled, delete the folder
`public/assets` then precompile again (see earlier for the command).


#### Deploying on Heroku

On Heroku, the `initialize` flag must be `false`. The following link may
provide some insight about what to do:

* [https://github.com/rails/rails/issues/8941](https://github.com/rails/rails/issues/8941)

I apologise for the inconvenience, but I can't do much about a bug like
this that's been in Rails for at least two years, especially now that (at
the time of writing) Rails 4 is out so a Rails 3 fix is even more unlikely.


## Warnings from Nokogiri

From version 2.25, TrackRecord's test suite uses something called Capybara
for integration tests. This has an unavoidable but somewhat unfortunate
reliance on Nokogiri, an XML parser. It's a capable, but very big gem that
has a huge native extension which can take a long time to build and install.

* [https://github.com/jnicklas/capybara](https://github.com/jnicklas/capybara)
* [http://nokogiri.org](http://nokogiri.org)

Installing Nokogiri in earlier days used to be quite a fragile process with
a high chance of error (in my experience) but it's got a lot better since.
If you do encounter errors, though, you'll need to search the web for help.

A common run-time _warning_ however is a complaint that the LibXML version
used for building the gem differs from that being used at run-time. I got
this on OS X Mavericks with a _clean_ installation of the gem via `bundle`.
Advice online included things like uninstalling and reinstalling the gem
with simple commands that just didn't make any difference. In the end, I
installed it with explicit pointers to the libraries it would end up using
at run-time.

```sh
gem uninstall nokogiri     (...and answer "y" to everything)
gem install nokogiri -- --with-xml2-include=/usr/include/libxml2/libxml \
                        --with-xml2-lib=/usr/lib/ \
                        --with-sxlt-include=/usr/include/libxslt \
                        --with-xslt-lib=/usr/lib/
```

Yes, there really is meant to be that "` -- `" after `nokogiri`.

You might have to adapt that for different systems; for example, on a 64-bit
Linux, you'd probably need `/usr/lib64/` instead of `/usr/lib`. If you don't
need the documentation for Nokogiri installed locally - it takes ages! - then
add `--no-doc` just after `gem install nokogiri`, before the "` -- `". This
does mean you'd need to go online to read documentation rather than being
able to browse it via likes of `gem server` or the `ri` command.

You might need to repeat the above process if you upgrade your system and
your libraries change.

If this doesn't solve your warning problems, I'm afraid you'll have to start
searching the web for clues.


## TrackRecord Quick Start User Guide

### First time setup

The first time you use TrackRecord you'll be asked to provide an Open ID
for the person that'll become the first system administrator. More details
about OpenID are provided on the welcome page.

### Adding other users

To add new users to the system:

* The new user tells the admin what their preferred Open ID is
* The admin uses the "Manage users" link on their Home page control panel
  to add a new User entry with the required permissions and Open ID set
* The admin tells the new user that they're set up
* The new user can now log in

Only permitted Open IDs added by an administrator in this way will be able
to sign into the system.

### Customers, projects and tasks

A customer has many projects and a project has many tasks. Only admins are
able to create any of these entities.

#### Adding one at a time

When adding new customers etc. to the system, start with the customer,
then add the projects, then add the tasks. Always take care to assign the
correct task->project->customer ownership; you don't _have_ to assign a
task to a project, for example, but users can't add that task to a row in
their timesheet unti you do.

#### Bulk task import

It is possible to import tasks en masse from XML files exported by software
such as OpenProj or Microsoft Project. Use the "Bulk task import" link from
the Home page control panel and follow the instructions presented.

If your workflow is based around creating project plans before setting up
the timesheet system, this can be really useful as the project plan may be
used as the import data source.

### Permissions

Administrator users can do just about anything. Manager users can read
almost all data on the system, but can only edit their own data or the
timesheets of other users (so they can make corrections or adjustments if
necessary). Restricted users can only read data that they have created, or
that they are given explicit permission to see. An administrator must edit
the user's account and add a task list to it, so that the user is able to
do things with that task list - in particular, they can't add task rows
to their timesheets unless the admin has given them permission to "see"
those tasks.

Users can make temporary, or permanently saved reports. These can be
marked as "shared", in which case other users can see them. For managers
and admins it makes little difference as they can read any report anyway,
but for restricted users, a report made by someone else is only visible
if it is marked as shared.

### Timesheet committing

Timesheets are editable until committed, then they become frozen. This
leads to the notion of comitted versus non-committed hours in reports and
so forth. The idea is that at the end of a week, a user finishes editing
their timesheet and commits it using the relevant pop-up menu in the
timesheet editor. Thereafter, "history cannot be rewritten" - important if
you've used timesheet data in reports sent to clients.

For some workflows, you might want to commit less often, or you might find
that some users don't remember to commit timesheets when you expect them
to. Consequently, it's possible for admins to bulk commit timesheets that
lie between two given dates. Use the "Bulk timesheet commit" link on the
Home page control panel and follow the instructions provided.

### Audit trail

Changes to "important" objects like customers or timesheets are recorded
in detail in the audit trail. Admins can examine this if they need to see
who modified something and when. It's unlikely that you will need it, but
should anything unexpectedly change in a way that might be a problem for a
report or client, you do at least have this fallback to help work out what
happened. Follow the "Raw audit data" link on the Home Page control panel.
