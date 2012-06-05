require 'spec_helper'
require 'support/active_record'

describe Build do
  include Support::ActiveRecord

  let(:repository) { Factory(:repository) }

  describe 'class methods' do
    describe 'recent' do
      it 'returns recent builds that at least are started ordered by creation time descending' do
        Factory(:build, :state => 'finished')
        Factory(:build, :state => 'started')
        Factory(:build, :state => 'created')

        Build.recent.all.map(&:state).should == ['started', 'finished']
      end
    end

    describe 'was_started' do
      it 'returns builds that are either started or finished' do
        Factory(:build, :state => 'finished')
        Factory(:build, :state => 'started')
        Factory(:build, :state => 'created')

        Build.was_started.map(&:state).sort.should == ['finished', 'started']
      end
    end

    describe 'on_branch' do
      it 'returns builds that are on any of the given branches' do
        Factory(:build, :commit => Factory(:commit, :branch => 'master'))
        Factory(:build, :commit => Factory(:commit, :branch => 'develop'))
        Factory(:build, :commit => Factory(:commit, :branch => 'feature'))

        Build.on_branch('master,develop').map(&:commit).map(&:branch).sort.should == ['develop', 'master']
      end
    end

    describe 'older_than' do
      before do
        5.times { |i| Factory(:build, :number => i) }
        Build.stubs(:per_page).returns(2)
      end

      context "when a Build is passed in" do
        subject { Build.older_than(Build.new(:number => 3)) }

        it "should limit the results" do
          should have(2).items
        end

        it "should return older than the passed build" do
          subject.map(&:number).should == ['2', '1']
        end
      end

      context "when a number is passed in" do
        subject { Build.older_than(3) }

        it "should limit the results" do
          should have(2).items
        end

        it "should return older than the passed build" do
          subject.map(&:number).should == ['2', '1']
        end
      end

      context "when not passing a build" do
        subject { Build.older_than() }

        it "should limit the results" do
          should have(2).item
        end
      end
    end

    describe 'paged' do
      it 'limits the results to the `per_page` value' do
        3.times { Factory(:build) }
        Build.stubs(:per_page).returns(1)

        Build.paged({}).should have(1).item
      end

      it 'uses an offset' do
        3.times { |i| Factory(:build) }
        Build.stubs(:per_page).returns(1)

        builds = Build.paged({:page => 2})
        builds.should have(1).item
        builds.first.number.should == '2'
      end
    end

    describe 'next_number' do
      it 'returns the next build number' do
        1.upto(3) do |number|
          Factory(:build, :repository => repository, :number => number)
          repository.builds.next_number.should == number + 1
        end
      end
    end

    describe 'pushes' do
      before do
        Factory(:build)
        Factory(:build, :request => Factory(:request, :event_type => ''))
        Factory(:build, :request => Factory(:request, :event_type => 'pull_request'))
      end

      it "returns only builds which have Requests with an event_type of push" do
        Build.pushes.all.count.should == 2
      end
    end

    describe 'pull_requests' do
      before do
        Factory(:build)
        Factory(:build, :request => Factory(:request, :event_type => ''))
        Factory(:build, :request => Factory(:request, :event_type => 'pull_request'))
      end

      it "returns only builds which have Requests with an event_type of pull_request" do
        Build.pull_requests.all.count.should == 1
      end
    end
  end

  describe 'instance methods' do
    it 'sets its number to the next build number on creation' do
      1.upto(3) do |number|
        Factory(:build).reload.number.should == number.to_s
      end
    end

    it 'sets previous_build_result to nil if no last build exists on the same branch' do
      build = Factory(:build, :result => 1, :commit => Factory(:commit, :branch => 'master'))
      build.previous_result.should == nil
    end

    it 'sets previous_build_result to the result of the last build on the same branch if exists' do
      build = Factory(:build, :result => 1, :commit => Factory(:commit, :branch => 'master'))
      build = Factory(:build, :commit => Factory(:commit, :branch => 'master'))
      build.previous_result.should == 1
    end

    describe 'config' do
      it 'defaults to an empty hash' do
        Build.new.config.should == {}
      end

      it 'deep_symbolizes keys on write' do
        build = Factory(:build, :config => { 'foo' => { 'bar' => 'bar' } })
        build.config[:foo][:bar].should == 'bar'
      end

      it 'tries to deserialize the config itself if a String is returned' do
        build = Factory(:build)
        build.stubs(:read_attribute).returns("---\n:foo:\n  :bar: bar")
        Build.logger.expects(:warn)
        build.config[:foo][:bar].should == 'bar'
      end
    end

    describe :pending? do
      it 'returns true if the build is finished' do
        build = Factory(:build, :state => :finished)
        build.pending?.should be_false
      end

      it 'returns true if the build is not finished' do
        build = Factory(:build, :state => :started)
        build.pending?.should be_true
      end
    end

    describe :passed? do
      it 'passed? returns true if result is 0' do
        build = Factory(:build, :result => 0)
        build.passed?.should be_true
      end

      it 'passed? returns true if result is 1' do
        build = Factory(:build, :result => 1)
        build.passed?.should be_false
      end
    end

    describe :result_message do
      it 'returns "Passed" if the build has passed' do
        build = Factory(:build, :result => 0, :state => :finished)
        build.result_message.should == 'Passed'
      end

      it 'returns "Failed" if the build has failed' do
        build = Factory(:build, :result => 1, :state => :finished)
        build.result_message.should == 'Failed'
      end

      it 'returns "Pending" if the build is pending' do
        build = Factory(:build, :result => nil, :state => :started)
        build.result_message.should == 'Pending'
      end
    end

    describe :color do
      it 'returns "green" if the build has passed' do
        build = Factory(:build, :result => 0, :state => :finished)
        build.color.should == 'green'
      end

      it 'returns "red" if the build has failed' do
        build = Factory(:build, :result => 1, :state => :finished)
        build.color.should == 'red'
      end

      it 'returns "yellow" if the build is pending' do
        build = Factory(:build, :result => nil, :state => :started)
        build.color.should == 'yellow'
      end
    end

    xit "finds the previous finished build on the same repository and branch" do
      repo   = Factory(:repository, :name => "test")
      commit = Factory(:commit, :branch => "test")

      Factory(:successful_build, :repository => repo, :commit => commit)
      Factory(:successful_build, :repository => repo, :commit => commit)
      Factory(:broken_build,     :repository => repo, :commit => commit)
      Factory(:successful_build, :repository => repo)
      build = Factory(:successful_build, :repository => repo, :commit => commit)
      previous = build.previous_finished_on_branch
      previous.number.should == "3"
      previous.passed?.should == false
      build.result_message.should == "Fixed"
    end
  end
end
