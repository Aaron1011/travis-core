require 'active_support/core_ext/hash/except'

module Travis
  module Services
    class UpdateJob < Base
      extend Travis::Instrumentation

      register :update_job

      EVENT = [:start, :finish, :reset]

      def run
        job.send(:"#{event}!", data.except(:id))
      end
      instrument :run

      def job
        @job ||= Job::Test.find(data[:id])
      end

      def event
        params[:event]
      end

      def data
        @data ||= begin
          data = params[:data].symbolize_keys
          # TODO remove once workers send the state
          data[:state] = { 0 => :passed, 1 => :failed }[data.delete(:result)] if data.key?(:result)
          data
        end
      end

      def event
        @event ||= EVENT.detect { |event| event == params[:event].try(:to_sym) } || raise_unknown_event
      end

      def raise_unknown_event
        raise ArgumentError, "Unknown event: #{params[:event]}, data: #{data}"
      end

      class Instrument < Notification::Instrument
        def run_completed
          publish(
            msg: "event: #{target.event} for <Job id=#{target.data[:id]}> data=#{target.data.inspect}",
            job_id: target.data[:id],
            event: target.event,
            data: target.data
          )
        end
      end
      Instrument.attach_to(self)
    end
  end
end

