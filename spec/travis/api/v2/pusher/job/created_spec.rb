require 'spec_helper'

describe Travis::Api::V2::Pusher::Job::Created do
  include Travis::Testing::Stubs, Support::Formats

  let(:data) { Travis::Api::V2::Pusher::Job::Created.new(test).data }

  before :each do
    test.stubs(state: :created)
  end

  it 'job' do
    data['job'].should == {
      'id' => 1,
      'repository_id' => 1,
      'repository_slug' => 'svenfuchs/minimal',
      'build_id' => 1,
      'commit_id' => 1,
      'log_id' => 1,
      'number' => '2.1',
      'state' => 'created',
      'started_at' => json_format_time(Time.now.utc - 1.minute),
      'finished_at' => json_format_time(Time.now.utc),
      'config' => { 'rvm' => '1.8.7', 'gemfile' => 'test/Gemfile.rails-2.3.x' },
      'queue' => 'builds.linux',
      'allow_failure' => false,
      'tags' => 'tag-a,tag-b'
    }
  end

  it 'commit' do
    data['commit'].should == {
      'id' => 1,
      'sha' => '62aae5f70ceee39123ef',
      'message' => 'the commit message',
      'branch' => 'master',
      'message' => 'the commit message',
      'committed_at' => json_format_time(Time.now.utc - 1.hour),
      'committer_name' => 'Sven Fuchs',
      'committer_email' => 'svenfuchs@artweb-design.de',
      'author_name' => 'Sven Fuchs',
      'author_email' => 'svenfuchs@artweb-design.de',
      'compare_url' => 'https://github.com/svenfuchs/minimal/compare/master...develop',
    }
  end
end
