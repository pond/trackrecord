Trackrecord::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # If you are not running in the root of your domain, set this variable
  # to indicate the location. You must do this for asset precompilation
  # to work properly, even if you are using something like Passenger which
  # takes care of such things for you normally.
  #
  # So for example, if running from "http://www.test.com/trackrecord/", set
  # a value of '/trackrecord'.
  config.relative_url_root = ''

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  # - to test precompiled assets under Webrick or similar ("rails s") set this
  # to "true" and run the in production mode (e.g. "rails s -e production" or
  # an equivalent command, "RAILS_ENV=production rails s")
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Make sure asset precompilation is aware of environment settings
  config.assets.initialize_on_precompile = true

  # Precompile *all* assets, except those that start with underscore. See:
  #
  #   http://blog.55minutes.com/2012/02/untangling-the-rails-asset-pipeline-part-3-configuration/
  #
  # Precompile with this rather convulted command:
  #
  #   RAILS_ENV=production bundle exec rake assets:precompile
  #
  config.assets.precompile << /(^[^_\/]|\/[^_])[^\/]*$/

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
end
