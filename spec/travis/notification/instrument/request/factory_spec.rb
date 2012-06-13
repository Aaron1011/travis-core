require 'spec_helper'

describe Travis::Notification::Instrument::Request::Factory do
  include Support::ActiveRecord

  let(:data)      { JSON.parse(GITHUB_PAYLOADS['pull-request']) }
  let(:factory)   { Request::Factory.new('pull_request', data, 'token') }
  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:event)     { publisher.events.first }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    factory.request
  end

  it 'publishes a payload' do
    event.should == {
      :msg => 'Request::Factory#request type="pull_request"',
      :type => 'pull_request',
      :token => 'token',
      :accept? => true,
      :data => data,
      :result => nil,
      :uuid => Travis.uuid
    }
  end
end
