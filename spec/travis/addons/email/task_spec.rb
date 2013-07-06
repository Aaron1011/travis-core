require 'spec_helper'

describe Travis::Addons::Email::Task do
  include Travis::Testing::Stubs

  let(:subject)    { Travis::Addons::Email::Task }
  let(:mailer)     { Travis::Addons::Email::Mailer::Build }
  let(:payload)    { Travis::Api.data(build, for: 'event', version: 'v0').deep_symbolize_keys }
  let(:email)      { stub('email', deliver: true) }
  let(:handler)    { subject.new(payload, recipients: recipients, broadcasts: broadcasts) }
  let(:broadcasts) { [broadcast] }

  attr_reader :recipients

  before :each do
    @recipients = ['svenfuchs@artweb-design.de']
    mailer.stubs(:finished_email).returns(email)
    Broadcast.stubs(:by_repo).returns(broadcasts)
  end

  it 'creates an email for the build email recipients' do
    mailer.expects(:finished_email).with(payload, recipients, broadcasts).returns(email)
    handler.run
  end

  it 'sends the email' do
    email.expects(:deliver)
    handler.run
  end

  it 'includes valid email addresses' do
    @recipients = ['me@email.org']
    handler.recipients.should contain_recipients('me@email.org')
  end

  it 'ignores email addresses (me@email)' do
    @recipients = ['me@email']
    handler.recipients.should_not contain_recipients('me@email')
  end

  it 'ignores email address ending in .local' do
    @recipients = ['me@email.local']
    handler.recipients.should_not contain_recipients('me@email.local')
  end
end
