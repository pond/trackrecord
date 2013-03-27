# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Trackrecord::Application.config.secret_token = 'see above'

# When you've set the key above, you can delete or comment out this
# "raise" line below.
raise "Before you can start TrackRecord, you must set a key in config/initializers/secret_token.rb and keep it secret!"
