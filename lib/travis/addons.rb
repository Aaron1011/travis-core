module Travis
  module Addons
    autoload :Campfire,     'travis/addons/campfire'
    autoload :Email,        'travis/addons/email'
    autoload :Flowdock,     'travis/addons/flowdock'
    autoload :GithubStatus, 'travis/addons/github_status'
    autoload :Hipchat,      'travis/addons/hipchat'
    autoload :Irc,          'travis/addons/irc'
    autoload :Pusher,       'travis/addons/pusher'
    autoload :Util,         'travis/addons/util'
    autoload :Webhook,      'travis/addons/webhook'
    autoload :Librato,      'travis/addons/librato'

    class << self
      def register
        constants(false).each do |name|
          key = name.to_s.underscore
          const = const_get(name)
          handler = const.const_get(:EventHandler) rescue nil
          Travis::Event::Subscription.register(key, handler) if handler
          const.setup if const.respond_to?(:setup)
        end
      end
    end
  end
end
