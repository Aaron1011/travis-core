require 'spec_helper'

describe Travis::Services::Repositories::All do
  include Support::ActiveRecord

  let!(:repo)   { Factory(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let(:service) { Travis::Services::Repositories::All.new(stub('user'), params) }

  attr_reader :params

  describe 'run' do
    it 'finds repositories by a given list of ids' do
      @params = { :ids => [repo.id] }
      service.run.should == [repo]
    end

    it 'returns the recent timeline when given empty params' do
      @params = {}
      service.run.should include(repo)
    end

    describe 'given a member name' do
      it 'finds a repository where that member has permissions' do
        @params = { :member => 'joshk' }
        repo.users << Factory(:user, :login => 'joshk')
        service.run.should include(repo)
      end

      it 'does not find a repository where the member does not have permissions' do
        @params = { :member => 'joshk' }
        service.run.should_not include(repo)
      end
    end

    describe 'given an owner_name name' do
      it 'finds a repository with that owner_name' do
        @params = { :owner_name => 'travis-ci' }
        service.run.should include(repo)
      end

      it 'does not find a repository with another owner name' do
        @params = { :owner_name => 'sinatra' }
        service.run.should_not include(repo)
      end
    end

    describe 'given a slug name' do
      it 'finds a repository with that slug' do
        @params = { :slug => 'travis-ci/travis-core' }
        service.run.should include(repo)
      end

      it 'does not find a repository with a different slug' do
        @params = { :slug => 'travis-ci/travis-hub' }
        service.run.should_not include(repo)
      end
    end

    describe 'given a search phrase' do
      it 'finds a repository matching that phrase' do
        @params = { :search => 'travis' }
        service.run.should include(repo)
      end

      it 'does not find a repository that does not match that phrase' do
        @params = { :search => 'sinatra' }
        service.run.should_not include(repo)
      end
    end
  end
end
