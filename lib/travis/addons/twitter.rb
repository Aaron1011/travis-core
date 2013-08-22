module Travis
  module Addons
    module Twitter
      autoload :EventHandler, 'travis/addons/twitter/event_handler'
      autoload :Instruments,  'travis/addons/twitter/instruments'
      autoload :Task,         'travis/addons/twitter/task'
    end
  end
end
