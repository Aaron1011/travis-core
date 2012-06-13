require 'spec_helper'

describe Travis::Notification::Instrument::Task::Webhook do
  include Travis::Testing::Stubs

  let(:data)      { Travis::Api.data(build, :for => 'webhook', :type => 'build/finished', :version => 'v1') }
  let(:task)      { Travis::Task::Webhook.new(data, :targets => 'http://example.com') }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:event)     { publisher.events.first }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    task.stubs(:process)
    task.run
  end

  it 'publishes a payload' do
    event.except(:data).should == {
      :msg => 'Travis::Task::Webhook#run for #<Build id=1>',
      :repository => 'svenfuchs/minimal',
      :object_id => 1,
      :object_type => 'Build',
      :targets => 'http://example.com',
      :result => nil,
      :uuid => Travis.uuid
    }
    event[:data].should_not be_nil
  end
end

