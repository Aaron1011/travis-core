require 'active_support/concern'
require 'simple_states'

class Request
  module States
    extend ActiveSupport::Concern
    include Travis::Event

    included do
      include SimpleStates

      states :created, :started, :finished
      event :start,     :to => :started, :after => :configure
      event :configure, :to => :configured, :after => :finish
      event :finish,    :to => :finished
      event :all, :after => :notify
    end

    def configure
      if !accepted?
        Travis.logger.warn("[request:configure] Request not accepted: event_type=#{event_type.inspect} commit=#{commit.try(:commit).inspect} message=#{approval.message.inspect}")
      elsif config.present?
        Travis.logger.warn("[request:configure] Request not configured: config not blank, config=#{config.inspect} commit=#{commit.try(:commit).inspect}")
      else
        self.config = fetch_config

        if branch_accepted?
          Travis.logger.info("[request:configure] Request successfully configured commit=#{commit.commit.inspect}")
        else
          self.config = nil
          Travis.logger.warn("[request:configure] Request not accepted: event_type=#{event_type.inspect} commit=#{commit.try(:commit).inspect} message=#{approval.message.inspect}")
        end
      end
      save!
    end

    def finish
      if config.blank?
        Travis.logger.warn("[request:finish] Request not creating a build: config is blank, config=#{config.inspect} commit=#{commit.try(:commit).inspect}")
      elsif !approved?
        Travis.logger.warn("[request:finish] Request not creating a build: not approved commit=#{commit.try(:commit).inspect} message=#{approval.message.inspect}")
      else
        add_build
        Travis.logger.info("[request:finish] Request created a build. commit=#{commit.try(:commit).inspect}")
      end
      self.result = approval.result
      self.message = approval.message
      Travis.logger.info("[request:finish] Request finished. result=#{result.inspect} message=#{message.inspect} commit=#{commit.try(:commit).inspect}")
    end

    protected

      delegate :accepted?, :approved?, :branch_accepted?, :to => :approval

      def approval
        @approval ||= Approval.new(self)
      end

      def fetch_config
        Travis.run_service(:github_fetch_config, request: self) # TODO move to a service, have it pass the config to configure
      end

      def add_build
        builds.create!(:repository => repository, :commit => commit, :config => config, :owner => owner)
      end
  end
end
