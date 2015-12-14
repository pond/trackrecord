# GEM / BUNDLE INSTALLATION
# =========================
#
# You'll need the "bundler" gem installed in your current gem set for the
# version of Ruby you're using with TrackRecord. You also need Bundler version
# 1.6 or later. Do this to see what version you have:
#
#   bundle --version
#
# If the "bundle" command is not found then the "bundler" gem is probably not
# installed, so try "gem install bundler". If the version is too old, try
# "gem update bundler". Depending on your OS and Ruby setup, you might need
# superuser privilege for these commands; e.g. do "sudo gem install bundler"
# on Unix-like operating systems such as Linux or OS X.
#
# To install all of the gem for TrackRecord, including those only for testing
# or development, use:
#
#   bundle install
#
# Since test gems require Nokogiri and other relatively heavy gems which
# can be cumbersome to install, it (and "thin", a web server used for
# development) are kept in groups. You can easily avoid bundling them for
# production with:
#
#   bundle install --without development test
#
# ...noting that *THIS PERSISTS* on subsequent "bundle install" commands.
# List such persisted settings with:
#
#   bundle config
#
# ...and undo the "--without" using something like:
#
#   bundle config --delete without
#
# For more information about Bundler "remembered settings" and how to manage
# them, see:
#
# * http://bundler.io/v1.6/man/bundle-install.1.html#REMEMBERED-OPTIONS
# *  http://stackoverflow.com/questions/9765007/how-do-you-undo-bundle-install-without

source 'http://rubygems.org'

# The following line requires Bundler v1.2 or later; see:
# http://gembundler.com/v1.2/whats_new.html
ruby '2.1.6'

gem 'rails', '3.2.18'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

gem 'pg', '>=0.17.1' # 0.16 or later is essential if using PostgreSQL with TrackRecord as it means PostgreSQL 0.8.4 or later are present; for more on this or using other databases, see doc/README_FOR_APP.
gem 'json'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'therubyracer'
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
end

gem 'prototype-rails'

# Uncomment to use thin as the 'rails server' web server.
# gem 'thin'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug'

# For a Rails' has_secure_password (or equivalent - see the User model
# implementation for details):
# 
# https://github.com/codahale/bcrypt-ruby/tree/master

gem 'bcrypt', '~> 3.1.7'

# https://github.com/timcharper/calendar_date_select (original, but not Rails 3 compatible)
#       http://github.com/paneq/calendar_date_select (Rails 3 fork)
#       https://github.com/pond/calendar_date_select (my fork to ensure survival)
# https://github.com/openid/ruby-openid
# https://github.com/grosser/open_id_authentication
# https://github.com/mislav/will_paginate/
# https://github.com/collectiveidea/audited
# https://github.com/swanandp/acts_as_list
# https://github.com/pond/safe_in_place_editing
# https://github.com/fnando/browser

gem 'calendar_date_select',   '~> 1.16', :git => 'https://github.com/pond/calendar_date_select.git'
gem 'ruby-openid',            '~> 2.5'     
gem 'open_id_authentication', '~> 1.2'
gem 'will_paginate',          '~> 3.0'
gem 'audited-activerecord',   '~> 3.0'
gem 'acts_as_list'
gem 'safe_in_place_editing',  '~> 2.0.1'
gem 'browser', '~> 0.4'

# For testing:
#
# https://github.com/jnicklas/capybara
# https://github.com/teampoltergeist/poltergeist
# https://github.com/bmabey/database_cleaner
# https://github.com/macournoyer/thin/
#
# The 'thin' server is specified as the stock Rails 3 server caused lots
# of problems in Safari with blank pages; looks like Safari's fault, but
# that doesn't help solve the problem! Thin is faster anyway.
#
# IMPORTANT: For Poltergeist, you'll need PhantomJS installed. See the
# Poltergeist documentation at GitHub for details:
#
#   https://github.com/teampoltergeist/poltergeist

group :test do
  gem 'capybara', '~> 2.2'
  gem 'poltergeist', '~> 1.5'
  gem 'database_cleaner', '~> 1.2'
end

group :test, :development do
  gem 'thin'
end

# If you want the charting stuff for some reason... Note that
# this brings in awkward dependencies such as ImageMagick via
# rmagick.
#
# https://github.com/topfunky/gruff
#
# gem 'gruff'            
# gem 'rmagick', :require => false

# https://github.com/tenderlove/rails_autolink
# https://github.com/joelmoss/dynamic_form

gem 'rails_autolink'
gem 'dynamic_form'

# Visualisation aid - for more information, see:
# http://railroady.prestonlee.com/

# gem 'railroady'
