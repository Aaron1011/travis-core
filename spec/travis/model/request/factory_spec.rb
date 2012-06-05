require 'spec_helper'

describe Request do
  include Support::ActiveRecord

  let(:payload) { GITHUB_PAYLOADS['gem-release'] }
  let(:owner)   { User.first || Factory(:user) }

  describe 'create_from' do
    shared_examples_for 'creates a request and repository' do
      it 'creates a request for the given payload' do
        expect { request }.to change(Request, :count).by(1)
      end

      it 'creates a repository' do
        expect { request }.to change(Repository, :count).by(1)
      end

      it 'sets the payload to the request' do
        request.payload.should == payload
      end

      it 'sets the token to the request' do
        request.token.should == 'token'
      end
    end

    shared_examples_for 'sets the owner for the request and repository to the expected type and login' do |type, login|
      it 'sets the repository owner' do
        request.repository.owner.should be_a(type.camelize.constantize)
      end

      it 'sets the request owner' do
        request.owner.should be_a(type.camelize.constantize)
      end

      it_should_behave_like 'has the expected login for the request and repository owner', login
    end

    shared_examples_for 'has the expected login for the request and repository owner' do |login|
      it 'has the repository owner login' do
        request.repository.owner.login.should == login
      end

      it 'has the request owner login' do
        request.owner.login.should == login
      end
    end

    shared_examples_for 'creates a commit and configure job' do
      it 'creates a commit' do
        expect { request }.to change(Commit, :count).by(1)
      end

      it 'creates a configure job' do
        expect { request }.to change(Job::Configure, :count).by(1)
      end
    end

    shared_examples_for 'sets the owner for the configure job to the expected type and login' do |type, login|
      it 'sets the configure job owner' do
        request.job.owner.should be_a(type.camelize.constantize)
      end

      it_should_behave_like 'has the expected login for the configure job owner', login
    end

    shared_examples_for 'has the expected login for the configure job owner' do |login|
      it 'sets the configure job owner login' do
        request.job.owner.login.should == login
      end
    end

    shared_examples_for 'does not create a configure job' do
      it 'does not create a configure job' do
        expect { request }.not_to change(Job::Configure, :count)
      end
    end

    shared_examples_for 'creates an object from the github api' do |type, login|
      it 'creates the object' do
        expect { request }.to change(type.camelize.constantize, :count).by(1)
      end

      it 'calls the github api to populate the user' do
        resource = type == 'organization' ? "orgs/#{login}" : "users/#{login}"
        GH.expects(:[]).with(resource).returns(:name => login.camelize, :login => login)
        request
      end
    end

    shared_examples_for 'does not create a user' do
      it 'does not create a user' do
        expect { request }.not_to change(User, :count)
      end
    end

    shared_examples_for 'does not create an organization' do
      it 'does not create an organization' do
        expect { request }.not_to change(Organization, :count)
      end
    end

    shared_examples_for 'an accepted request' do |type, login|
      it_should_behave_like 'creates a request and repository'
      it_should_behave_like 'sets the owner for the request and repository to the expected type and login', type, login
      it_should_behave_like 'creates a commit and configure job'
      it_should_behave_like 'sets the owner for the configure job to the expected type and login', type, login
    end

    shared_examples_for 'a rejected request' do |type, login|
      it_should_behave_like 'creates a request and repository'
      it_should_behave_like 'sets the owner for the request and repository to the expected type and login', type, login
      it_should_behave_like 'does not create a configure job'
    end

    describe 'a github push event' do
      let(:request) { Request.create_from('push', payload, 'token') }

      describe 'with a payload that contains a commit' do
        describe 'for repository belonging to a user' do
          let(:payload) { GITHUB_PAYLOADS['gem-release'] }

          login = 'svenfuchs'
          type  = 'user'

          describe 'if the user exists' do
            before(:each) { Factory(:user, :login => login) }
            it_should_behave_like 'an accepted request', type, login
            it_should_behave_like 'does not create a user'
          end

          describe 'if the user does not exist' do
            before(:each) { User.delete_all }
            it_should_behave_like 'an accepted request', type, login
            it_should_behave_like 'creates an object from the github api', type, login
          end
        end

        describe 'for repository belonging to an organization' do
          let(:payload) { GITHUB_PAYLOADS['travis-core'] }

          login = 'travis-ci'
          type  = 'organization'

          describe 'if the organization exists' do
            before(:each) { Factory(:org, :login => login) }
            it_should_behave_like 'an accepted request', type, login
            it_should_behave_like 'does not create an organization'
          end

          describe 'if the organization does not exist' do
            before(:each) { Organization.delete_all }
            it_should_behave_like 'an accepted request', type, login
            it_should_behave_like 'creates an object from the github api', type, login
          end
        end
      end

      describe 'with a payload that does not contain a commit' do
        describe 'for a repository belonging to a user' do
          let(:payload) { GITHUB_PAYLOADS['force-no-commit'] }

          login = 'LTe'
          type  = 'user'

          describe 'if the user exists' do
            before(:each) { Factory(:user, :login => login) }
            it_should_behave_like 'a rejected request', type, login
            it_should_behave_like 'does not create a user'
          end

          describe 'if the user does not exist' do
            before(:each) { User.delete_all }
            it_should_behave_like 'a rejected request', type, login
            it_should_behave_like 'creates an object from the github api', type, login
          end
        end

        describe 'for a repository belonging to an organization' do
          let(:payload) { GITHUB_PAYLOADS['travis-core-no-commit'] }

          login = 'travis-ci'
          type  = 'organization'

          describe 'if the organization exists' do
            before(:each) { Factory(:org, :login => login) }
            it_should_behave_like 'a rejected request', type, login
            it_should_behave_like 'does not create an organization'
          end

          describe 'if the organization does not exist' do
            before(:each) { Organization.delete_all }
            it_should_behave_like 'a rejected request', type, login
            it_should_behave_like 'creates an object from the github api', type, login
          end
        end
      end
    end
  end

  describe 'a github pull-request event' do
    describe 'for a repository that belongs to an organization' do
      let(:request) { Request.create_from('pull_request', payload, 'token') }
      let(:payload) { GITHUB_PAYLOADS['pull-request'] }

      login = 'travis-repos'
      type  = 'organization'

      describe 'if the organization exists' do
        before(:each) { Factory(:org, :login => login) }
        it_should_behave_like 'an accepted request', type, login
        it_should_behave_like 'does not create an organization'

        it 'sets the comments_url to the request' do
          request.comments_url.should == 'https://api.github.com/repos/travis-repos/test-project-1/issues/1/comments'
        end
      end

      describe 'if the organization does not exist' do
        before(:each) { Organization.delete_all }
        it_should_behave_like 'an accepted request', type, login
        it_should_behave_like 'creates an object from the github api', type, login

        it 'sets the comments_url to the request' do
          request.comments_url.should == 'https://api.github.com/repos/travis-repos/test-project-1/issues/1/comments'
        end
      end
    end
  end
end
