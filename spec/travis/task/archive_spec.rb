require 'spec_helper'
require 'support/active_record'
require 'support/formats'

describe Travis::Task::Archive do
  include Support::ActiveRecord
  include Support::Formats

  let(:io)       { StringIO.new }
  let(:http)     { Faraday::Adapter::Test::Stubs.new }
  let(:client)   { Faraday.new { |f| f.request :url_encoded; f.adapter(:test, http) } }

  let(:build)    { Factory(:build, :created_at => Time.utc(2011, 1, 1), :config => { :rvm => ['1.9.2', 'rbx'] }) }
  let(:data)     { Travis::Api.data(build, :for => 'archive', :version => 'v1') }

  before do
    Travis.logger = Logger.new(io)
    Travis.config.archive = { :host => 'host', :username => 'username', :password => 'password' }
    Travis::Task::Archive.any_instance.stubs(:http).returns(client)
  end

  def run
    Travis::Task::Archive.new(data).run
  end

  describe 'run' do
    before :each do
      http.put("/builds/#{build.id}") {[ 200, {}, 'ok' ]}
    end

    it 'stores the build payload to the storage' do
      run
      http.verify_stubbed_calls
    end

    it 'sets the build to be archived' do
      run
      build.reload.archived_at.should_not be_nil
    end
  end

  describe 'logging' do
    it 'logs a successful request' do
      http.put("/builds/#{build.id}") {[ 200, {}, 'ok' ]}
      run
      io.string.should include("[archive] Successfully archived http://username:password@host/builds/#{build.id}")
    end

    it 'warns about a failed request' do
      http.put("/builds/#{build.id}") {[ 403, {}, 'nono.' ]}
      run
      io.string.should include(%([archive] Could not archive to http://username:password@host/builds/#{build.id}. Status: 403 (\"nono.\")))
    end
  end
end

