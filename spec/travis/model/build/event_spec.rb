require 'spec_helper'
require 'support/active_record'

describe Build::Event do
  include Support::ActiveRecord # TODO why do we need active_record here?
  include Build::Event

  let(:config)     { }
  let(:commit)     { stub('commit', :committer_email => 'commiter@email.org', :author_email => 'author@email.org') }
  let(:repository) { stub('repository', :owner_email => 'owner@email.org', :key => SslKey.new.tap { |k| k.generate_keys }) }

  before(:each) do
    stubs(:pull_request? => false, :previous_result => nil).returns false
  end

  describe :notify_on_finish_for? do
    it 'returns true by default' do
      send_email_notifications_on_finish?.should be_true
    end

    it 'returns false if the build is a pull-request' do
      stubs(:pull_request?).returns true
      send_email_notifications_on_finish?.should be_false
    end

    it 'returns false if the build does not have any recipients' do
      stubs(:email_recipients).returns('')
      send_email_notifications_on_finish?.should be_false
    end

    it 'returns false if the build has notifications disabled (deprecated api) (disabled => true)' do
      stubs(:config => { :notifications => { :disabled => true } })
      send_email_notifications_on_finish?.should be_false
    end

    it 'returns false if the build has notifications disabled (deprecated api) (disable => true)' do
      stubs(:config => { :notifications => { :disable => true } })
      send_email_notifications_on_finish?.should be_false
    end

    it 'returns false if the build has notifications disabled' do
      stubs(:config => { :notifications => { :email => false } })
      send_email_notifications_on_finish?.should be_false
    end

    it "returns true if the given build failed and previous build failed" do
      stubs(:passed? => false, :failed? => true, :previous_result => 1)
      send_email_notifications_on_finish?.should be_true
    end

    it "returns true if the given build failed and previous build passed" do
      stubs(:passed? => false, :failed? => true, :previous_result => 0)
      send_email_notifications_on_finish?.should be_true
    end

    it "returns true if the given build passed and previous build failed" do
      stubs(:passed? => true, :failed? => false, :previous_result => 1)
      send_email_notifications_on_finish?.should be_true
    end

    it "returns false if the given build passed and previous build passed" do
      stubs(:passed? => true, :failed? => false, :previous_result => 0)
      send_email_notifications_on_finish?.should be_false
    end

    combinations = [
      [nil, true,  { :notifications => { :on_failure => 'always' } }, true ],
      [0,   true,  { :notifications => { :on_success => 'always' } }, true ],
      [1,   true,  { :notifications => { :on_success => 'always' } }, true ],
      [nil, false, { :notifications => { :on_failure => 'always' } }, true ],
      [0,   false, { :notifications => { :on_failure => 'always' } }, true ],
      [1,   false, { :notifications => { :on_failure => 'always' } }, true ],

      [nil, true,  { :notifications => { :on_failure => 'change' } }, true ],
      [0,   true,  { :notifications => { :on_success => 'change' } }, false],
      [1,   true,  { :notifications => { :on_success => 'change' } }, true ],
      [nil, false, { :notifications => { :on_failure => 'change' } }, true ],
      [0,   false, { :notifications => { :on_failure => 'change' } }, true ],
      [1,   false, { :notifications => { :on_failure => 'change' } }, false],

      [nil, true,  { :notifications => { :on_success => 'never'  } }, true], # TODO this sounds wrong
      [0,   true,  { :notifications => { :on_success => 'never'  } }, false],
      [1,   true,  { :notifications => { :on_success => 'never'  } }, false],
      [nil, false, { :notifications => { :on_success => 'never'  } }, true],
      [0,   false, { :notifications => { :on_success => 'never'  } }, true],
      [1,   false, { :notifications => { :on_success => 'never'  } }, true],

      [nil, true,  { :notifications => { :on_failure => 'never'  } }, true],
      [0,   true,  { :notifications => { :on_failure => 'never'  } }, false],
      [1,   true,  { :notifications => { :on_failure => 'never'  } }, true],
      [nil, false, { :notifications => { :on_failure => 'never'  } }, true], # TODO this sounds wrong
      [0,   false, { :notifications => { :on_failure => 'never'  } }, false],
      [1,   false, { :notifications => { :on_failure => 'never'  } }, false],
    ]
    results = { true => 'passed', false => 'failed' }

    combinations.each do |previous, current, config, result|
      it "returns #{result} if the previous result was #{previous.inspect}, the current build #{results[current]} and config is #{config}" do
        stubs(:config => config, :passed? => current, :failed? => !current, :previous_result => previous)
        send_email_notifications_on_finish?.should == result
      end
    end
  end

  describe :email_recipients do
    it 'contains the author emails if the build has them set' do
      commit.stub(:author_email => 'author-1@email.com,author-2@email.com')
      email_recipients.should contain_recipients(commit.author_email)
    end

    it 'contains the committer emails if the build has them set' do
      commit.stub(:committer_email => 'committer-1@email.com,committer-2@email.com')
      email_recipients.should contain_recipients(commit.committer_email)
    end

    it "contains the build's repository owner_email if it has one" do
      repository.stub(:owner_email => 'owner-1@email.com,owner-2@email.com')
      email_recipients.should contain_recipients(commit.committer_email)
    end

    it "contains the build's repository owner_email if it has a configuration but no emails specified" do
      stubs(:config => {})
      repository.stub(:owner_email => 'owner-1@email.com')
      email_recipients.should contain_recipients(repository.owner_email)
    end

    it "equals the recipients specified in the build configuration if any (given as an array)" do
      recipients = %w(recipient-1@email.com recipient-2@email.com)
      stubs(:config => { :notifications => { :recipients => recipients } })
      email_recipients.should contain_recipients(recipients)
    end

    it "equals the recipients specified in the build configuration if any (given as a string)" do
      recipients = 'recipient-1@email.com,recipient-2@email.com'
      stubs(:config => { :notifications => { :recipients => recipients } })
      email_recipients.should contain_recipients(recipients)
    end
  end

  describe :send_webhook_notifications_on_finish? do
    it 'returns true if the build configuration specifies webhooks' do
      webhooks = %w(http://evome.fr/notifications http://example.com/)
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      send_webhook_notifications_on_finish?.should be_true
    end

    it 'returns false if the build is a pull-request' do
      stubs(:pull_request?).returns true
      send_webhook_notifications_on_finish?.should be_false
    end

    it 'returns false if the build configuration does not specify any webhooks' do
      webhooks = %w(http://evome.fr/notifications http://example.com/)
      stubs(:config => {})
      send_webhook_notifications_on_finish?.should be_false
    end
  end

  describe :send_campfire_notifications_on_finish? do
    it 'returns true if the build configuration specifies campfire channels' do
      channels = %w(travis:apitoken@42)
      stubs(:config => { :notifications => { :campfire => channels } })
      send_campfire_notifications_on_finish?.should be_true
    end

    it 'returns false if the build is a pull-request' do
      stubs(:pull_request?).returns true
      send_webhook_notifications_on_finish?.should be_false
    end

    it 'returns false if the build configuration does not specify any webhooks' do
      stubs(:config => {})
      send_campfire_notifications_on_finish?.should be_false
    end
  end

  describe :webhooks do
    it 'returns an array of urls when given a string' do
      webhooks = 'http://evome.fr/notifications'
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      self.webhooks.should == [webhooks]
    end

    it 'returns an array of urls when given an array' do
      webhooks = ['http://evome.fr/notifications']
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      self.webhooks.should == webhooks
    end

    it 'returns an array of multiple urls when given a comma separated string' do
      webhooks = 'http://evome.fr/notifications, http://example.com'
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      self.webhooks.should == webhooks.split(' ').map(&:strip)
    end

    it 'returns an array of urls if the build configuration specifies an array of urls' do
      webhooks = %w(http://evome.fr/notifications http://example.com)
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      self.webhooks.should == webhooks
    end

    it 'returns an array of values if the build configuration specifies an array of urls within a config hash' do
      webhooks = { :urls => %w(http://evome.fr/notifications http://example.com), :on_success => 'change' }
      stubs(:config => { :notifications => { :webhooks => webhooks } })
      self.webhooks.should == webhooks[:urls]
    end
  end

  describe :campfire_rooms do
    it 'returns an array of urls when given a string' do
      channels = 'travis:apitoken@42'
      stubs(:config => { :notifications => { :campfire => channels } })
      self.campfire_rooms.should == [channels]
    end

    it 'returns an array of urls when given an array' do
      channels = ['travis:apitoken@42']
      stubs(:config => { :notifications => { :campfire => channels } })
      self.campfire_rooms.should == channels
    end

    it 'returns an array of multiple urls when given a comma separated string' do
      channels = 'travis:apitoken@42,evome:apitoken@44'
      stubs(:config => { :notifications => { :campfire => channels } })
      self.campfire_rooms.should == channels.split(' ').map(&:strip)
    end

    it 'returns an array of values if the build configuration specifies an array of urls within a config hash' do
      channels = { :rooms => %w(travis:apitoken&42), :on_success => 'change' }
      stubs(:config => { :notifications => { :campfire => channels } })
      self.campfire_rooms.should == channels[:rooms]
    end
  end


  describe :irc_channels do
    it 'returns an array of urls when given a string' do
      channels = 'irc.freenode.net#travis'
      stubs(:config => { :notifications => { :irc => channels } })
      self.irc_channels.should == { ['irc.freenode.net', nil] => ['travis'] }
    end

    it 'returns an array of urls when given an array' do
      channels = ['irc.freenode.net#travis', 'irc.freenode.net#rails']
      stubs(:config => { :notifications => { :irc => channels } })
      self.irc_channels.should == { ['irc.freenode.net', nil] => ['travis', 'rails'] }
    end

    it 'returns an array of urls when given a string on the channels key' do
      channels = 'irc.freenode.net#travis'
      stubs(:config => { :notifications => { :irc => { :channels => channels } } })
      self.irc_channels.should == { ['irc.freenode.net', nil] => ['travis'] }
    end

    it 'returns an array of urls when given an array on the channels key' do
      channels = ['irc.freenode.net#travis', 'irc.freenode.net#rails']
      stubs(:config => { :notifications => { :irc => { :channels => channels } } })
      self.irc_channels.should == { ['irc.freenode.net', nil] => ['travis', 'rails'] }
    end

    it 'groups irc channels by host & port, so notifications can be sent with one connection' do
      stubs(:config => { :notifications => { :irc => %w(
        irc.freenode.net:1234#travis
        irc.freenode.net#rails
        irc.freenode.net:1234#travis-2
        irc.example.com#travis-3
      )}})
      irc_channels.should == {
        ["irc.freenode.net", '1234'] => ['travis', 'travis-2'],
        ["irc.freenode.net", nil]    => ['rails'],
        ["irc.example.com",  nil]    => ['travis-3']
      }
    end
  end
end
