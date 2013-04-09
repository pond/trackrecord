# https://github.com/rails/rails/issues/4277

Rails.logger.instance_variable_get(:@logger).instance_variable_get(:@log_dest).sync = true if Rails.logger
