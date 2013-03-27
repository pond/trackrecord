########################################################################
# File::    email_config.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Configuration data for e-mail notification messages. See
#           models/email_notifier.rb for more.
# ----------------------------------------------------------------------
#           04-Jun-2008 (ADH): Created.
#           15-Oct-2009 (ADH): Removed PATH_PREFIX mechanism.
########################################################################

# Administrator e-mail address to use as the 'From' address in
# account notification e-mail messages.
EMAIL_ADMIN = 'please@configure.this.address'

# Prefix to use in subject lines of account notification e-mail
# messages, including trailing spaces if you want a space between
# your prefix and the subject text.
EMAIL_PREFIX = '[TrackRecord] '

# Hostname to use in notification messages. The controller/action
# data will be appended to it.
EMAIL_HOST = 'please.configure.this.domain'
