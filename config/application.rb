require File.expand_path('../boot', __FILE__)
require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  # Bundler.require *Rails.groups(:assets => %w(development test))
  # If you want your assets lazily compiled in production, use this line
  Bundler.require(:default, :assets, Rails.env)
end

module Trackrecord
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.log_level = :debug

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # 2011-10-06 (ADH): This is a particularly stupid aspect of Rails 3. It no
    # longer auto-loads code in "lib", leaving you to either manually require
    # it with the implication that just a single file needs the module (but in
    # that case, why's it a module in the first place?) and actually, you're
    # then *not* supposed to require it, because requiring inside applications
    # might break ActiveSupport::Dependencies' (un)loading of code. So in
    # short, if you ever want to put code in "lib", you *must* add this hack.
    # So remind me why the framework suddenly decided to stop doing this itself
    # again? Just to make developers jump through yet *more* pointless hoops
    # for the gratification of the core team? Sigh, sigh, and thrice sigh.
    #
    # 2013-07-26 (ADH): More sighing! This still doesn't eager-load classes in
    # the library folder, so when trying to implement plugin report generators
    # via the TrackRecordReportGenerator* class hierarchy, subclasses would not
    # be loaded and attempts to enumerate them through Base's ".subclasses"
    # would fail. Thus in addition to the line below, please note that there's
    # an "eager_load_report_generators.rb" patch inside "config/initializers".
    # Rails 4 introduces eager loading formally. Facepalm.
    #
    config.autoload_paths += Dir["#{config.root}/lib", "#{config.root}/lib/**/"]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.1'
  end
end
