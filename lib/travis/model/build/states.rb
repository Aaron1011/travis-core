require 'active_support/concern'
require 'simple_states'

class Build

  # A Build goes through the following lifecycle:
  #
  #  * A newly created Build is in the `created` state.
  #  * When started it sets its `started_at` attribute from the given
  #    (worker) payload.
  #  * A build won't be restarted if it already is started (each matrix job
  #    will try to start it).
  #  * A build will be finished only if all matrix jobs are finished (each
  #    matrix job will try to finish it).
  #  * After both `start` and `finish` events the build will denormalize
  #    attributes to its repository and notify event listeners.
  module States
    extend ActiveSupport::Concern
    include Denormalize, Travis::Event

    included do
      include SimpleStates

      states :created, :started, :passed, :failed, :errored, :canceled

      event :start,  to: :started,  unless: :started?
      event :finish, to: :finished, if: :matrix_finished?
      event :reset,  to: :created
      event :all, after: [:denormalize, :notify]

      # after_create do
      #   notify(:create)
      # end
    end

    def start(data = {})
      self.started_at = data[:started_at]
    end

    def finish(data = {})
      self.state = matrix_state
      self.duration = matrix_duration
      self.finished_at = data[:finished_at]
    end

    def reset(options = {})
      self.state = :created
      %w(duration started_at finished_at).each { |attr| write_attribute(attr, nil) }
      matrix.each(&:reset!) if options[:reset_matrix]
    end

    def resetable?
      finished?
    end

    def pending?
      created? || started?
    end

    def finished?
      passed? || failed? || errored? || canceled? || state.try(:to_s) == 'finished' # TODO remove once we've migrated
    end

    def color
      pending? ? 'yellow' : passed? ? 'green' : 'red'
    end

    def notify(event, *args)
      event = :create if event == :reset
      super
    end
  end
end
