########################################################################
# File::    configure_openid_logging.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Tell ruby-openid to use the Rails logger.
# ----------------------------------------------------------------------
#           05-Jul-2008 (ADH): Created.
########################################################################

OpenID::Util::logger = Rails.logger

