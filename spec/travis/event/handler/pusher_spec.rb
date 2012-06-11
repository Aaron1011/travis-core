require 'spec_helper'

describe Travis::Event::Handler::Pusher do
  include Travis::Testing::Stubs

  let(:handler) { Travis::Event::Handler::Pusher.any_instance }

  before do
    Travis::Event.stubs(:subscribers).returns [:pusher]
    handler.stubs(:handle => true, :handle? => true)
  end

  describe 'subscription' do
    it 'job:test:created' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:created', test)
    end

    it 'job:test:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:started', test)
    end

    it 'job:log' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:log', test)
    end

    it 'job:test:finished' do
      handler.expects(:notify)
      Travis::Event.dispatch('job:test:finished', test)
    end

    it 'build:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('build:started', build)
    end

    it 'build:finished' do
      handler.expects(:notify)
      Travis::Event.dispatch('build:finished', build)
    end

    it 'worker:started' do
      handler.expects(:notify)
      Travis::Event.dispatch('worker:started', worker)
    end
  end

  describe 'instrumentation' do
    it 'instruments with "travis.event.handler.pusher.notify:call"' do
      ActiveSupport::Notifications.expects(:instrument).with do |event, data|
        event == 'travis.event.handler.pusher.notify:call' && data[:target].is_a?(Travis::Event::Handler::Pusher)
      end
      Travis::Event.dispatch('build:finished', build)
    end

    it 'meters on "travis.event.handler.pusher.notify:call"' do
      Metriks.expects(:timer).with('travis.event.handler.pusher.notify:call').returns(stub('timer', :update => true))
      Travis::Event.dispatch('build:finished', build)
    end
  end
end
