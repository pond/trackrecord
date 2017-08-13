require File.expand_path('../boot', __FILE__)
require 'rails/all'

if defined?(Bundler)
  # Require the gems listed in Gemfile, including any gems
  # you've limited to :test, :development, or :production.
  Bundler.require(*Rails.groups)
end

module Trackrecord
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.log_level = :info

    # 2014-03-19 (ADH): In Rails 3.2.15 and earlier, an invalid locate given to
    # I18n would result in automatic fallback to 'en'. In 3.2.16 or later this
    # assumed behaviour would raise a warning. The line below would set a value
    # of 'false' to explicitly request old-style behaviour with no warnings.
    # Instead, we say 'true' to request errors if invalid locates are given.
    #
    config.i18n.enforce_available_locales = true

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

    # 2014-03-25 (ADH): It seems that at some point Rails changed from using
    # a class name of "fieldWithErrors" on errant form fields, to
    # "field_with_errors". The "errorExplanation" DIV hasn't changed name.
    # Sigh, sigh, thrice sigh... To avoid CSS changes, which would include
    # changes in Calendar Date Select CSS - a third party gem - override
    # Rails and put back the old name. How silly that this is required.
    #
    config.action_view.field_error_proc = Proc.new { | html_tag, instance |
      "<div class=\"fieldWithErrors\">#{ html_tag }</div>".html_safe()
    }

    # Opt into exception raising in `after_rollback`/`after_commit` hooks
    # introduced in Rails 4.2, to avoid deprecation warnings.
    config.active_record.raise_in_transactional_callbacks = true

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

    # Enable the asset pipeline
    config.assets.enabled = true
    config.assets.precompile += %w( prototype/prototype.js prototype_ujs/rails.js scriptaculous/scriptaculous.js scriptaculous/effects.js scriptaculous/dragdrop.js scriptaculous/controls.js )
    config.assets.precompile += %w( leightbox/leightbox.js leightbox/leightbox.css )
    config.assets.precompile += %w( yui_tree/yui_tree_support.js )
    config.assets.precompile += %w( calendar_date_select/calendar_date_select.js calendar_date_select/default.css )

    config.assets.precompile += %w( application.js saved_reports.js sessions.js task_imports.js )
    config.assets.precompile += %w( trackrecord/check_box_toggler.js trackrecord/check_for_javascript.js trackrecord/global.js trackrecord/saved_report_editor.js trackrecord/section_revealer.js trackrecord/timesheet_editor.js trackrecord/timesheet_viewer.js )
    config.assets.precompile += %w( application.css scaffold.css trackrecord_all.css trackrecord_print.css )

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.2'
  end
end
