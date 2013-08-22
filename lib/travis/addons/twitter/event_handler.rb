module Travis
  module Addons
    module Twitter
      class EventHandler < Event::Handler
        EVENTS = /build:finished/

        def handle?
          !pull_request? && targets.present? && config.send_on_finished_for?(:twitter)
        end

        def handle
          Travis::Addons::Twitter::Task.run(:twitter, payload, targets: targets)
        end

        def targets
          @targets ||= config.notification_values(:twitter, :accounts)
        end

        Instruments::EventHandler.attach_to(self)
      end
    end
  end
end
