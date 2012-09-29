module Travis
  module Services
    module Users
      class Sync < Base
        def run
          unless current_user.syncing?
            publisher.publish({ user_id: current_user.id }, type: 'sync')
            current_user.update_column(:is_syncing, true)
          end
        end

        private

          def publisher
            Travis::Amqp::Publisher.new('sync.user')
          end
      end
    end
  end
end
