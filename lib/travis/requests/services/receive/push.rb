module Travis
  module Requests
    module Services
      class Receive < Travis::Services::Base
        class Push
          attr_reader :event

          def initialize(event)
            @event = event
          end

          def accept?
            true
          end

          def repository
            @repository ||= {
              :name        => event['repository']['name'],
              :description => event['repository']['description'],
              :url         => event['repository']['_links']['html']['href'],
              :owner_name  => event['repository']['owner']['login'],
              :owner_email => event['repository']['owner']['email'],
              :owner_type  => event['repository']['owner']['type'],
              :private     => !!event['repository']['private']
            }
          end

          def owner
            @owner ||= {
              :type  => event['repository']['owner']['type'],
              :login => event['repository']['owner']['login']
            }
          end

          def request
            @request ||= {}
          end

          def commit
            @commit ||= if commit = last_unskipped_commit(event['commits']) || event['commits'].last
              {
                :commit          => commit['sha'],
                :message         => commit['message'],
                :branch          => event['ref'].split('/', 3).last,
                :ref             => event['ref'],
                :committed_at    => commit['date'],
                :committer_name  => commit['committer']['name'],
                :committer_email => commit['committer']['email'],
                :author_name     => commit['author']['name'],
                :author_email    => commit['author']['email'],
                :compare_url     => event['compare']
              }
            end
          end

          private

          def last_unskipped_commit(commits)
            commits.reverse.find { |commit| !skip_commit?(commit) }
          end

          def skip_commit?(commit)
            Travis::CommitCommand.new(commit['message']).skip?
          end
        end
      end
    end
  end
end
