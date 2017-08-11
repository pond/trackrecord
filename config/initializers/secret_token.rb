# Be sure to restart your server when you modify this file.
#
# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
#
Trackrecord::Application.config.secret_token = ENV[ 'TRACKRECORD_SECRET_TOKEN' ] || '!'

unless Rails.env.test?
  if Trackrecord::Application.config.secret_token.length < 32
    raise "Before you can start TrackRecord, you must set a key in " +
          "config/initializers/secret_token.rb and keep it secret! " +
          "Set this in environment variable TRACKRECORD_SECRET_TOKEN " +
          "or, if you prefer, edit the file directly."
  end
end
