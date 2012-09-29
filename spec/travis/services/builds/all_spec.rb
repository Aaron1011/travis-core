require 'spec_helper'

describe Travis::Services::Builds::All do
  include Support::ActiveRecord

  let(:repo)    { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let!(:build)  { Factory(:build, :repository => repo, :state => :finished, :number => 1) }
  let(:service) { Travis::Services::Branches::All.new(stub('user'), params) }

  attr_reader :params

  describe 'run' do
    it 'finds recent builds when empty params given' do
      @params = { :repository_id => repo.id }
      service.run.should == [build]
    end

    it 'finds builds older than the given number' do
      @params = { :repository_id => repo.id, :after_number => 2 }
      service.run.should == [build]
    end

    it 'scopes to the given repository_id' do
      @params = { :repository_id => repo.id }
      Factory(:build, :repository => Factory(:repository), :state => :finished)
      service.run.should == [build]
    end

    it 'returns an empty build scope when the repository could not be found' do
      @params = { :repository_id => repo.id + 1 }
      service.run.should == Build.none
    end
  end
end
