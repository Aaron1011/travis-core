module Travis
  module Requests
    module Services
      autoload :Receive, 'travis/requests/services/receive'

      class << self
        def register
          constants(false).each { |name| const_get(name) }
        end
      end
    end
  end
end
