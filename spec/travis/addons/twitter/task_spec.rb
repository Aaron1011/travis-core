require 'spec_helper'
require 'rack'
require 'oauth'

describe Travis::Addons::Twitter::Task do
  include Travis::Testing::Stubs

  let(:subject)  { Travis::Addons::Twitter::Task }
  let(:payload)  { Travis::Api.data(build, for: 'event', version: 'v0') }
  let(:consumer) { mock('consumer') }
  let(:response) { mock('response') }
  let(:targets)  { targets = ['applepie'] }

  before do
    subject.any_instance.stubs(:consumer).returns(consumer)
  end

  def run(targets)
    subject.new(payload, targets: targets).run
  end

  it "sends Tweets to the given targets" do
    message = "svenfuchs/minimal#2 (master - 62aae5f): passed"
    expect_twitter("@applepie #{message}")
    run(targets)
  end

  it "using a custom template" do
    template = '%{repository} %{commit}'
    message = 'svenfuchs/minimal 62aae5f'
    payload['build']['config']['notifications'] = {twitter: { template: template } }

    expect_twitter("@applepie #{message}")
    run(targets)
  end

  def expect_twitter(message)
    body = { 'status' => message }
    ::OAuth::AccessToken.expects(:new).returns('Token')
    response.stubs(:code => '200')
    consumer.expects(:request).with(:post, '/1.1/statuses/update.json', 'Token', {:scheme => :query_string}, body).
      returns(response)

    #http.post('1.1\/statuses\/update\.json') do |env|
    #  env[:url].host.should == 'api.twitter.com'
    #  Rack::Utils.parse_query(env[:body]).should == body
    #end
  end
end
