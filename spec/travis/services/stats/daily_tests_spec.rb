require 'spec_helper'
require 'travis/testing/scenario'

describe Travis::Services::Stats::DailyTests do
  include Support::ActiveRecord

  let(:service) { Travis::Services::Stats::DailyTests.new(stub('user'), {}) }

  before { Scenario.default }

  describe 'run' do
    it 'should return the jobs per day' do
      stats = service.run
      stats.should have(1).item
      stats.first['date'].should == Job.first.created_at.to_date.to_s(:date)
      stats.first['count'].to_i.should == 13
    end
  end
end
