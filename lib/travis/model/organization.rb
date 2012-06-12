require 'gh'

class Organization < ActiveRecord::Base
  class << self
    def create_from_github(name)
      # TODO ask @rkh about this
      data = GH["orgs/#{name}"] || raise(Travis::GithubApiError)
      create!(:name => data['name'], :login => data['login'], :github_id => data['id'])
    end
  end

  has_many :memberships
  has_many :users, :through => :memberships
  has_many :repositories, :as => :owner

  def github_oauth_token
    users.first.try(:github_oauth_token)
  end
end

