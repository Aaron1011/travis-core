require 'active_record'

# Models an incoming request. The only supported source for requests currently is Github.
#
# The Request will be configured by fetching `.travis.yml` from the Github API
# and needs to be approved based on the configuration. Once approved the
# Request creates a Build.
class Request < ActiveRecord::Base
  autoload :Approval, 'travis/model/request/approval'
  autoload :Branches, 'travis/model/request/branches'
  autoload :Factory,  'travis/model/request/factory'
  autoload :States,   'travis/model/request/states'

  include States

  class << self
    def receive(type, data, token)
      request = Factory.new(type, data, token).request
      request.start! if request
    end

    def last_by_head_commit(head_commit)
      where(:head_commit => head_commit).order(:id).last
    end
  end

  belongs_to :commit
  belongs_to :repository
  belongs_to :owner, :polymorphic => true
  has_many   :builds

  validates :repository_id, :presence => true

  serialize :config

  def event_type
    read_attribute(:event_type) || 'push'
  end

  def pull_request?
    event_type == 'pull_request'
  end
end
