require 'active_support/core_ext/class/attribute'

module Travis
  module Github
    # encapsulates fetching a .travis.yml from a given commit's config_url
    class Config
      include Logging
      extend Instrumentation

      attr_accessor :url

      def initialize(url)
        @url = url
      end

      def fetch
        if response.success?
          parse(response.body)
        elsif response.status == 404
          { '.result' => 'not_found' }
        else
          { '.result' => 'server_error' }
        end
      end
      instrument :fetch

      private

        def parse(yaml)
          YAML.load(yaml).merge('.result' => 'configured')
        rescue StandardError, Psych::SyntaxError => e
          log_exception(e)
          { '.result' => 'parsing_failed' }
        end

        def response
          @response ||= http.get(url)
        end

        def http
          @http ||= Faraday.new(http_options) do |f|
            f.adapter :net_http
          end
        end

        def http_options
          { :ssl => Travis.config.ssl.compact }
        end

        Notification::Instrument::Github::Config.attach_to(self)
    end
  end
end


