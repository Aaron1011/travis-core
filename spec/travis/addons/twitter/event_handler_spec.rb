require 'spec_helper'

describe Travis::Addons::Twitter::EventHandler do
  include Travis::Testing::Stubs

  let(:subject) { Travis::Addons::Twitter::EventHandler }
  let(:payload) { Travis::Api.data(build, for: 'event', version: 'v0') }

  describe 'subscription' do
    let(:handler) { subject.any_instance }

    before :each do
      Travis::Event.stubs(:subscribers).returns [:twitter]
      handler.stubs(:handle => true, :handle? => true)
      Travis::Api.stubs(:data).returns(stub('data'))
    end

    it 'build:started does not notitfy' do
      handler.expects(:notify).never
      Travis::Event.dispatch('build:started', build)
    end

    it 'build:finish notifies' do
      handler.expects(:notify).once
      Travis::Event.dispatch('build:finished', build)
    end
  end

  describe 'handler' do
    let(:event) { 'build:finished' }
    let(:task) { Travis::Addons::Twitter::Task }

    before :each do
      build.stubs(:config => { :notifications => {:twitter => 'account' } })
    end

    def notify
      subject.notify(event, build)
    end

    it 'triggers a task if the build is not a pull request' do
      build.stubs(:pull_request?).returns(false)
      task.expects(:run).with(:twitter, payload, targets: ['account'])
      notify
    end

    it 'does not trigger a task if the build is a pull request' do
      build.stubs(:pull_request?).returns(true)
      task.expects(:run).never
      notify
    end

    it 'triggers a task if accounts are present' do
     build.stubs(:config => { :notifications => {:twitter => 'account' } })
     task.expects(:run).with(:twitter, payload, targets: ['account'])
     notify
    end

    it 'does not trigger a task if no accounts are present' do
      build.stubs(:config => { :notifications => {:twitter => [] } })
      task.expects(:run).never
      notify
    end

    it 'triggers a task if specified by the config' do
      Travis::Event::Config.any_instance.stubs(:send_on_finished_for?).with(:twitter).returns(true)
      task.expects(:run).with(:twitter, payload, targets: ['account'])
      notify
    end

    it 'does not trigger a task if specified by the config' do
      Travis::Event::Config.any_instance.stubs(:send_on_finished_for?).with(:twitter).returns(false)
      task.expects(:run).never
      notify
    end
  end

  describe :targets do
    let(:handler) { subject.new('build:finished', build, {}, payload) }

    it 'returns an array of accounts when given a string' do
      accounts = 'travisci'
      build.stubs(:config => { :notifications => { :twitter => accounts } })
      handler.targets.should == [accounts]
    end

    it 'returns an array of accounts when given an array' do
      accounts = ['travisci']
      build.stubs(:config => { :notifications => { :twitter => accounts } })
      handler.targets.should == accounts
    end

    it 'returns an array of multiple accounts when given a comma separated string' do
      accounts = 'travisci, konstantinhaase'
      build.stubs(:config => { :notifications => { :twitter => accounts } })
      handler.targets.should == accounts.split(',').map(&:strip)
    end

    it 'returns an array of values if the build configuration specifies an array of accounts within a config hash' do
      accounts = { :accounts => %w(travisci), :on_success => 'change' }
      build.stubs(:config => { :notifications => { :twitter => accounts } })
      handler.targets.should == accounts[:accounts]
    end
  end
end
