# frozen_string_literal: true

require './require_app'
require_app

run FinanceTracker::App.freeze.app
