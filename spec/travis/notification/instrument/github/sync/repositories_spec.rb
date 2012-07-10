require 'spec_helper'

describe Travis::Notification::Instrument::Github::Sync::Repositories do
  include Support::ActiveRecord

  let(:user)      { Factory(:user, :login => 'sven', :github_oauth_token => '123456') }
  let(:data)      { [{ 'name' => 'minimal', 'owner' => { 'login' => 'sven' }, 'permissions' => { 'admin' => true } }] }

  let(:publisher) { Travis::Notification::Publisher::Memory.new }
  let(:events)    { publisher.events }
  let(:sync)      { Travis::Github::Sync::Repositories.new(user) }

  before :each do
    Travis::Notification.publishers.replace([publisher])
    Travis::Github.stubs(:repositories_for).returns(data)
    sync.run
  end

  it 'publishes a payload on :run' do
    events[3].should == {
      :message => "travis.github.sync.repositories.run:completed",
      :payload => {
        :msg => %(Travis::Github::Sync::Repositories#run for #<User id=#{user.id} login="sven">),
        :result => [ { :id => Repository.last.id, :owner => 'sven', :name => 'minimal' }]
      },
      :uuid => Travis.uuid
    }
  end

  it 'publishes a payload on :fetch' do
    events[2].should == {
      :message => "travis.github.sync.repositories.fetch:completed",
      :payload => {
        :msg => %(Travis::Github::Sync::Repositories#fetch for #<User id=#{user.id} login="sven">),
        :result => data
      },
      :uuid => Travis.uuid
    }
  end
end
