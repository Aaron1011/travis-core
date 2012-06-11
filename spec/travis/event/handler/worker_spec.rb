require 'spec_helper'

describe Travis::Event::Handler::Worker do
  include Travis::Testing::Stubs

  describe 'notify' do
    let(:handler) { Travis::Event::Handler::Worker.new(:start, test) }
    let(:builds)  { stub('builds', :publish => true) }
    let(:payload) { Travis::Api.data(test, :for => 'worker', :type => 'Job::Test', :version => 'v0') }

    before :each do
      Travis::Event.stubs(:subscribers).returns [:worker]
      Travis::Amqp::Publisher.stubs(:builds).returns(builds)
    end

    it 'fetches a publisher for the given queue name (routing_key)' do
      Travis::Amqp::Publisher.expects(:builds).with('builds.common').returns(builds)
      handler.notify
    end

    it 'publishes the payload to the publisher' do
      builds.expects(:publish).with(payload, :properties => { :type => 'test' })
      handler.notify
    end
  end

  describe 'publisher' do
    it 'returns a publisher for "builds.common" for a test job' do
      handler = Travis::Event::Handler::Worker.new(:start, test)
      handler.send(:publisher).routing_key.should == test.queue
    end
  end

  describe 'payload_for' do
    it 'returns Travis::Event::Worker::Job::Test for a test job' do
      handler = Travis::Event::Handler::Worker.new(:start, test)
      handler.send(:payload).should == Travis::Api::V0::Worker::Job::Test.new(test).data
    end
  end

  describe 'instrumentation' do
    let(:handler) { Travis::Event::Handler::Worker.new(:start, test) }

    before :each do
      handler.stubs(:handle)
    end

    it 'instruments with "travis.event.handler.worker.notify:call"' do
      ActiveSupport::Notifications.expects(:instrument).with do |event, data|
        event == 'travis.event.handler.worker.notify:call' && data[:target].is_a?(Travis::Event::Handler::Worker)
      end
      handler.notify
    end

    it 'meters on "travis.event.handler.worker.notify:call"' do
      Metriks.expects(:timer).with('travis.event.handler.worker.notify:call').returns(stub('timer', :update => true))
      handler.notify
    end
  end
end
