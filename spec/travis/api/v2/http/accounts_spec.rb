require 'spec_helper'

describe Travis::Api::V2::Http::Accounts do
  include Travis::Testing::Stubs, Support::Formats

  let(:user)     { { 'id' => 1, 'type' => 'User', 'login' => 'sven', 'name' => 'Sven', 'repos_count' => 2 } }
  let(:org)      { { 'id' => 1, 'type' => 'Organization', 'login' => 'travis', 'name' => 'Travis', 'repos_count' => 1 } }

  let(:accounts) { [Account.new(user), Account.new(org)] }
  let(:data)     { Travis::Api::V2::Http::Accounts.new(accounts).data }

  # it 'user' do
  #   data['user'].should == {
  #     'id' => 1,
  #     'name' => 'Sven Fuchs',
  #     'login' => 'svenfuchs',
  #     'email' => 'svenfuchs@artweb-design.de',
  #     'gravatar_id' => '402602a60e500e85f2f5dc1ff3648ecb',
  #     'locale' => 'de',
  #     'is_syncing' => false,
  #     'synced_at' => json_format_time(Time.now.utc - 1.hour)
  #   }
  # end

  it 'accounts' do
    data[:accounts].should == [
      { 'id' => 1, 'login' => 'sven', 'name' => 'Sven', 'type' => 'user', 'reposCount' => 2 },
      { 'id' => 1, 'login' => 'travis', 'name' => 'Travis', 'type' => 'organization', 'reposCount' => 1 }
    ]
  end
end

