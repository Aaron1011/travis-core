require 'spec_helper'
require 'travis/testing/scenario'

describe Travis::Services::Stats::DailyRepos do
  include Support::ActiveRecord

  let(:service) { Travis::Services::Stats::DailyRepos.new(stub('user'), {}) }

  before { Scenario.default }

  describe 'run' do
    it 'should include the date' do
      stats = service.run
      stats.should have(1).items
      stats.first['date'].should == Repository.first.created_at.to_date.to_s(:date)
    end

    it 'should include the number per day' do
      stats = service.run
      stats.should have(1).items
      stats.first['count'].to_i.should == 2
    end
  end
end
