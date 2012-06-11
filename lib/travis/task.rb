require 'faraday'
require 'core_ext/hash/compact'
require 'active_support/core_ext/string'

module Travis
  class Task
    autoload :Archive,  'travis/task/archive'
    autoload :Campfire, 'travis/task/campfire'
    autoload :Email,    'travis/task/email'
    autoload :Github,   'travis/task/github'
    autoload :Irc,      'travis/task/irc'
    autoload :Pusher,   'travis/task/pusher'
    autoload :Webhook,  'travis/task/webhook'

    include Logging
    extend  Instrumentation, NewRelic, Exceptions::Handling, Async

    class << self
      def run(type, *args)
        const_get(type.to_s.camelize).new(*args).run
      end
    end

    attr_reader :data, :options

    def initialize(data, options = {})
      @data = data
      @options = options
    end

    def run
      process
    end

    rescues    :run, :from => Exception
    instrument :run
    new_relic  :run, :category => :task
    async      :run

    private

      def http
        @http ||= Faraday.new(http_options) do |f|
          f.request :url_encoded
          f.adapter :net_http
        end
      end

      def http_options
        { :ssl => Travis.config.ssl.compact }
      end
  end
end
