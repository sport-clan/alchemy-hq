module Mandar::Console
end

# mixins
require "mandar/console/data.rb"
require "mandar/console/forms.rb"
require "mandar/console/utils.rb"
require "mandar/console/render.rb"
require "mandar/console/table.rb"

# components
require "mandar/console/entropy.rb"
require "mandar/console/locksmanager.rb"
require "mandar/console/stager.rb"

# handlers
require "mandar/console/apihandler.rb"
require "mandar/console/consolehandler.rb"
require "mandar/console/deploy.rb"
require "mandar/console/grapher.rb"
require "mandar/console/home.rb"
require "mandar/console/password.rb"
require "mandar/console/server.rb"
require "mandar/console/status.rb"
require "mandar/console/type-edit.rb"
require "mandar/console/type-list.rb"
