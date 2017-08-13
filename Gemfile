##############################################################################
# Gemfile
#
# See "README.md" for installation details and information on ways in which
# you may need to modify this file.
##############################################################################

source 'http://rubygems.org'

if ENV[ 'RAILS_ENV' ] == 'test'
  regexp  = /(?:(\d+)\.)?(?:(\d+)\.)?(?:(\d+)\.\d+)/
  version = `ruby --version`.match( regexp )
  ruby( version )
else
  ruby '2.1.10'
end

gem 'rails', '4.2.5'

# Database support; change this to use other engines.
#
gem 'pg', '~> 0.21'

##############################################################################
# Mandatory components
##############################################################################

# Rails extensions:
#
#   https://github.com/joelmoss/dynamic_form
#   https://github.com/rails/sass-rails
#
gem 'prototype-rails', :git => 'https://github.com/rails/prototype-rails', :branch => '4.2'
gem 'sass-rails', '~> 4.0'

# The 'Thin' server is specified as some users in the field prefer to run
# TrackRecord lightweight on an intranet via "rails server"; Thin is a lot
# faster. See:
#
#   http://code.macournoyer.com/thin/
#
gem 'thin'

# For a Rails' has_secure_password (or equivalent - see the User model
# implementation for details).
#
#   https://github.com/codahale/bcrypt-ruby/tree/master
#
gem 'bcrypt', '~> 3.1.7'

# For all environments:
#
#   https://github.com/timcharper/calendar_date_select (original, but not Rails 3 compatible)
#         http://github.com/paneq/calendar_date_select (Rails 3 fork)
#         https://github.com/pond/calendar_date_select (my fork to ensure survival)
#
#   https://github.com/openid/ruby-openid
#   https://github.com/grosser/open_id_authentication
#   https://github.com/mislav/will_paginate/
#   https://github.com/collectiveidea/audited
#   https://github.com/swanandp/acts_as_list
#   https://github.com/fnando/browser
#   https://github.com/amerine/in_place_editing
#   https://github.com/tenderlove/rails_autolink
#   https://github.com/joelmoss/dynamic_form
#
gem 'calendar_date_select',   '~> 1.16', :git => 'https://github.com/pond/calendar_date_select.git'
gem 'ruby-openid',            '~> 2.5'
gem 'open_id_authentication', '~> 1.2'
gem 'will_paginate',          '~> 3.0'
gem 'audited',                '~> 4.5'
gem 'acts_as_list',           '~> 0.9'
gem 'browser',                '~> 0.4'
gem 'in_place_editing',       '~> 1.2'
gem 'rails_autolink',         '~> 1.1'
gem 'dynamic_form',           '~> 1.1'

# For development:
#
#   http://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#web-console
#   https://github.com/deivid-rodriguez/byebug
#
group :development do
  gem 'web-console', '~> 2.0'
  gem 'byebug'
end

# For testing:
#
#   https://github.com/jnicklas/capybara
#   https://github.com/teampoltergeist/poltergeist
#   https://github.com/bmabey/database_cleaner
#
# IMPORTANT: For Poltergeist, you'll need PhantomJS installed. See:
#
#   http://phantomjs.org
#   https://github.com/teampoltergeist/poltergeist
#
group :test do
  gem 'capybara',         '~> 2.2'
  gem 'poltergeist',      '~> 1.5'
  gem 'database_cleaner', '~> 1.2'
end

##############################################################################
# Optional components
##############################################################################

# If you want the charting stuff for some reason... Note that
# this brings in awkward dependencies such as ImageMagick via
# rmagick.
#
#   https://github.com/topfunky/gruff
#
# gem 'gruff'
# gem 'rmagick', :require => false

# Ootional visualisation aid - for more information, see:
#
#   http://railroady.prestonlee.com/
#
# gem 'railroady'
