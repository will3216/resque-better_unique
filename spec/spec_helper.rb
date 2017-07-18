require 'simplecov'
SimpleCov.start

require "bundler/setup"
require "resque/plugins/better_unique"
require 'redis'
require 'resque'


redis = Redis.new
Resque.redis = redis

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    redis.flushdb
  end
end
