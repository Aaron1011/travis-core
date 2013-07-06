require 'spec_helper'
require 'rack'

describe Travis::Addons::Hipchat::Task do
  include Travis::Testing::Stubs

  let(:subject) { Travis::Addons::Hipchat::Task }
  let(:http)    { Faraday::Adapter::Test::Stubs.new }
  let(:client)  { Faraday.new { |f| f.request :url_encoded; f.adapter :test, http } }
  let(:payload) { Travis::Api.data(build, for: 'event', version: 'v0') }

  before do
    subject.any_instance.stubs(:http).returns(client)
  end

  def run(targets)
    subject.new(payload, targets: targets).run
  end

  it "sends hipchat notifications to the given targets" do
    targets = ['12345@room_1', '23456@room_2', '34567@[Dev] room3']
    message = [
      'svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): the build has passed',
      'Change view: https://github.com/svenfuchs/minimal/compare/master...develop',
      'Build details: http://travis-ci.org/svenfuchs/minimal/builds/1'
    ]

    expect_hipchat('room_1', '12345', message)
    expect_hipchat('room_2', '23456', message)
    expect_hipchat('[Dev] room3', '34567', message)

    run(targets)
    http.verify_stubbed_calls
  end

  it 'using a custom template' do
    targets  = ['12345@room_1']
    template = ['%{repository}', '%{commit}']
    messages = ['svenfuchs/minimal', '62aae5f']

    payload['build']['config']['notifications'] = { hipchat: { template: template } }
    expect_hipchat('room_1', '12345', messages)

    run(targets)
    http.verify_stubbed_calls
  end

  it "sends HTML notifications if requested" do
    targets = ['12345@room_1']
    template = ['<a href="%{build_url}">Details</a>']
    messages = ['<a href="http://travis-ci.org/svenfuchs/minimal/builds/1">Details</a>']

    payload['build']['config']['notifications'] = { hipchat: { template: template, format: 'html' } }
    expect_hipchat('room_1', '12345', messages, 'message_format' => 'html')

    run(targets)
    http.verify_stubbed_calls
  end

  it 'works with a list as HipChat configuration' do
    targets  = ['12345@room_1']
    template = ['%{repository}', '%{commit}']
    messages = [
      'svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): the build has passed',
      'Change view: https://github.com/svenfuchs/minimal/compare/master...develop',
      'Build details: http://travis-ci.org/svenfuchs/minimal/builds/1'
    ]

    payload['build']['config']['notifications'] = { hipchat: [] }
    expect_hipchat('room_1', '12345', messages)

    run(targets)
    http.verify_stubbed_calls
  end

  def expect_hipchat(room_id, token, lines, extra_body={})
    Array(lines).each do |line|
      body = { 'room_id' => room_id, 'from' => 'Travis CI', 'message' => line, 'color' => 'green', 'message_format' => 'text' }.merge(extra_body)
      http.post("v1/rooms/message?format=json&auth_token=#{token}") do |env|
        env[:url].host.should == 'api.hipchat.com'
        Rack::Utils.parse_query(env[:body]).should == body
      end
    end
  end
end

