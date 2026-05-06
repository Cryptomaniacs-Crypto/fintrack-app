# frozen_string_literal: true

# Requires all ruby files in specified app folders
# Params:
# - (opt) folders: Array of root folder names, or String of single folder name
# Usage:
#  require_app
#  require_app('config')
#
def require_app(folders = %w[services controllers])
  app_list = Array(folders).map { |folder| "app/#{folder}" }
  full_list = ['config', app_list].flatten.join(',')

  # Ensure base controller loads first (for class reopen patterns)
  base_controller = './app/controllers/app.rb'
  require base_controller if File.exist?(base_controller)

  Dir.glob("./{#{full_list}}/**/*.rb").sort.each do |file|
    next if file == base_controller
    require file
  end
end
