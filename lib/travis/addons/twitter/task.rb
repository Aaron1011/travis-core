require 'oauth'

module Travis
  module Addons
    module Twitter
      class Task < Travis::Task
        DEFAULT_TEMPLATE = "%{repository}#%{build_number} (%{branch} - %{commit}): %{result}"

        def targets
          params[:targets]
        end

        def message
          @message ||= Util::Template.new(template, payload).interpolate
        end

        private
          def process
            Array(targets).each { |target| post_tweet('@' + target, message) }
          end

          def post_tweet(target, lines)
            params = {'status' => "#{target} #{lines}"}

            access_token = ::OAuth::AccessToken.new(consumer, config[:access_token], config[:access_token_secret])
            response = consumer.request(:post, "/1.1/statuses/update.json", access_token,
                                        {:scheme => :query_string}, params)
            if response.code !~ /^2\d\d/
              log_error(target, response)
            end
          end

          def template
            template = config.fetch(:template, DEFAULT_TEMPLATE)
          end

          def config
            build[:config][:notifications][:twitter] rescue {}
          end

          def consumer
            @consumer ||= ::OAuth::Consumer.new(config[:consumer_key], config[:consumer_secret], {:site => "http://api.twitter.com"})
          end

          def log_error(target, response)
            error "Could not send tweet to #{target.to_s}. Status: #{response.code} (#{response.body.inspect})"
          end

          Instruments::Task.attach_to(self)
      end
    end
  end
end
