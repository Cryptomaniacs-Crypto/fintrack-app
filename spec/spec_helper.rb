# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/rg'
require_relative 'test_load_all'

API_URL = ENV.fetch('FINTRACK_API_URL', 'http://localhost:9292')