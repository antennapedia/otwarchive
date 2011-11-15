require 'redis_test_setup'
include RedisTestSetup

rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../../..'
rails_env = ENV['RAILS_ENV'] || 'development'

if rails_env == "test"
  # https://gist.github.com/441072
  start_redis!(rails_root, :cucumber)
end

redis_config = YAML.load_file(rails_root + '/config/redis.yml')

redis_setup = redis_config[rails_env]
if redis_setup.kind_of?({}.class)
	$redis = Redis.new(redis_setup)
else
	host, port = redis_setup.split(':')
	$redis = Redis.new(:host => host, :port => port)
end
