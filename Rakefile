# frozen_string_literal: true

require 'rake/testtask'
require './require_app'

task default: :spec

task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run tests'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.warning = false
end

desc 'Rerun tests on live code changes'
task :respec do
  sh 'rerun -c rake spec'
end

desc 'Run application console (pry)'
task console: [:print_env] do
  sh 'pry -r ./spec/test_load_all'
end

desc 'Run rubocop to check style'
task :style do
  sh 'rubocop .'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Checks for release'
task release: %i[spec style audit] do
  puts "\nReady for release!"
end

namespace :run do
  desc 'Run Web App in development mode'
  task dev: [:print_env] do
    sh 'puma -p 9292'
  end
end

task :load_lib do
  require_relative 'app/lib/secure_message'
  require_relative 'app/lib/secure_session'
end

namespace :generate do
  desc 'Create cookie secret'
  task session_secret: [:load_lib] do
    require 'rbnacl'
    require 'base64'
    puts "New SESSION_SECRET (base64): #{Base64.urlsafe_encode64(RbNaCl::Random.random_bytes(64))}"
  end

  desc 'Create message encryption key for MSG_KEY'
  task msg_key: [:load_lib] do
    puts "MSG_KEY: #{FinanceTracker::SecureMessage.generate_key}"
  end
end

namespace :newkey do
  desc 'Create rbnacl SecretBox key for SecureMessage (sessions, tokens)'
  task msg: [:load_lib] do
    puts "New MSG_KEY (base64): #{FinanceTracker::SecureMessage.generate_key}"
  end
end

namespace :session do
  desc 'Wipe all sessions stored in Redis session store'
  task wipe: [:load_lib] do
    require 'openssl'

    redis_url = ENV['REDISCLOUD_URL'] || ENV.fetch('REDIS_URL', nil)
    raise 'REDISCLOUD_URL or REDIS_URL is required' unless redis_url

    redis_server =
      if redis_url.start_with?('rediss://')
        { url: redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        redis_url
      end

    FinanceTracker::SecureSession.setup(redis_server)
    puts 'Deleting all sessions from Redis session store'
    wiped_count = FinanceTracker::SecureSession.wipe_redis_sessions
    puts "#{wiped_count} sessions deleted"
  end
end

namespace :url do
  # usage: $ rake url:integrity URL=http://example.org/script.js
  desc 'Generate SRI integrity hash for a URL (argument: URL=...)'
  task :integrity do
    sha384 = `curl -L -s #{ENV.fetch('URL', nil)} | openssl dgst -sha384 -binary | openssl enc -base64 -A`
    puts "sha384-#{sha384}"
  end
end
