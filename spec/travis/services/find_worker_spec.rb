require 'spec_helper'

describe Travis::Services::FindWorker do
  include Support::Redis

  let(:worker)  { Worker.create }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  it 'finds a worker by its id' do
    @params = { id: worker.id }
    service.run.should == worker
  end

  it 'does not raise if the worker could not be found' do
    @params = { id: 0 }
    lambda { service.run }.should_not raise_error
  end
end
