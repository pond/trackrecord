# See "README.md" for installation details and information on ways in which
# you may need to modify this file.

source 'http://rubygems.org'
ruby '2.1.10'

gem 'rails', '4.2.5'

gem 'pg', '~> 0.21'

gem 'prototype-rails', :git => 'https://github.com/rails/prototype-rails', :branch => '4.2'

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
#
gem 'bcrypt', '~> 3.1.7'

# https://github.com/timcharper/calendar_date_select (original, but not Rails 3 compatible)
#       http://github.com/paneq/calendar_date_select (Rails 3 fork)
#       https://github.com/pond/calendar_date_select (my fork to ensure survival)
#
# https://github.com/openid/ruby-openid
# https://github.com/grosser/open_id_authentication
# https://github.com/mislav/will_paginate/
# https://github.com/collectiveidea/audited
# https://github.com/swanandp/acts_as_list
# https://github.com/fnando/browser
# https://github.com/amerine/in_place_editing
#
gem 'calendar_date_select',   '~> 1.16', :git => 'https://github.com/pond/calendar_date_select.git'
gem 'ruby-openid',            '~> 2.5'
gem 'open_id_authentication', '~> 1.2'
gem 'will_paginate',          '~> 3.0'
gem 'audited',                '~> 4.5'
gem 'acts_as_list'
gem 'browser',                '~> 0.4'
gem 'in_place_editing'

# http://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#web-console
#
group :development do
  gem 'web-console', '~> 2.0'
end

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
# IMPORTANT: For Poltergeist, you'll need PhantomJS installed. See:
#
#   http://phantomjs.org
#   https://github.com/teampoltergeist/poltergeist
#
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
