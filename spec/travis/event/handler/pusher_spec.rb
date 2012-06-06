require 'spec_helper'

describe Travis::Event::Handler::Pusher do
  let(:object)    { stub('object') }
  let(:handler)   { Travis::Event::Handler::Pusher.any_instance }

  before do
    Travis.config.notifications = [:pusher]
  end

  describe 'subscription' do
    it 'job:configure:created' do
      handler.expects(:notify).never
      Travis::Event.dispatch('job:configure:created', object)
    end

    it 'job:configure:finished' do
      handler.expects(:notify).never
      Travis::Event.dispatch('job:configure:finished', object)
    end

    it 'job:test:created' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:created', object)
    end

    it 'job:test:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:started', object)
    end

    it 'job:log' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:log', object)
    end

    it 'job:test:finished' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:finished', object)
    end

    it 'build:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('build:started', object)
    end

    it 'build:finished' do
      handler.expects(:notify)
      Travis::Event.dispatch('build:finished', object)
    end

    it 'worker:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('worker:started', object)
    end
  end
end
