require 'base64'

module Travis
  module Event

    # Decrypts a single configuration value from a configuration file using the
    # repository's SSL key.
    #
    # This is used so people can add encrypted sensitive data to their
    # `.travis.yml` file.
    class SecureConfig
      def self.decrypt(config, key)
        self.new(key).decrypt(config)
      end

      attr_reader :key

      def initialize(key)
        @key = key
      end

      def decrypt(config)
        return config if config.is_a?(String)

        config.inject(config.class.new) do |result, element|
          key, element = element if result.is_a?(Hash)
          process(result, key, decrypt_element(key, element))
        end
      end

      private

        def decrypt_element(key, element)
          if element.is_a?(Array) || element.is_a?(Hash)
            decrypt(element)
          elsif key == :secure
            decrypt_value(element)
          else
            element
          end
        end

        def process(result, key, value)
          if result.is_a?(Array)
            result << value
          elsif result.is_a?(Hash) && !secure_key?(key)
            result[key] = value
            result
          else
            value
          end
        end

        def decrypt_value(value)
          decoded = Base64.decode64(value)
          key.decrypt(decoded)
        rescue OpenSSL::PKey::RSAError => e
          value
        end

        def secure_key?(key)
          key && key == :secure
        end
    end
  end
end
