# frozen_string_literal: true

namespace :run do
  desc 'Run app in development mode on :9090'
  task :dev do
    sh 'rerun -- puma -p 9090'
  end
end

namespace :generate do
  desc 'Print a fresh 64-byte session secret to paste into config/secrets.yml'
  task :session_secret do
    require 'securerandom'
    puts SecureRandom.hex(64)
  end
end

desc 'Run rubocop'
task :style do
  sh 'rubocop .'
end

desc 'Open a pry console with the app loaded'
task :console do
  sh 'pry -r ./app/controllers/app'
end
