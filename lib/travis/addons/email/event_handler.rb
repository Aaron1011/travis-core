module Travis
  module Addons
    module Email

      # Sends out build notification emails using ActionMailer.
      class EventHandler < Event::Handler
        API_VERSION = 'v2'

        EVENTS = 'build:finished'

        def handle?
          !pull_request? && config.enabled?(:email) && config.send_on_finished_for?(:email) && recipients.present?
        end

        def handle
          Travis::Addons::Email::Task.run(:email, payload, recipients: recipients, broadcasts: broadcasts)
        end

        def recipients
          @recipients ||= begin
            recipients = config.notification_values(:email, :recipients)
            recipients = config.notifications[:recipients] if recipients.blank? # TODO deprecate recipients
            recipients = default_recipients                if recipients.blank?
            Array(recipients).join(',').split(',').map(&:strip).select(&:present?).uniq
          end
        end

        private

          def pull_request?
            build['pull_request']
          end

          def broadcasts
            Broadcast.by_repo(object.repository).map do |broadcast|
              { message: broadcast.message }
            end
          end

          def default_recipients
            [commit['committer_email'], commit['author_email'], repository['owner_email']]
          end

          Instruments::EventHandler.attach_to(self)
      end
    end
  end
end
