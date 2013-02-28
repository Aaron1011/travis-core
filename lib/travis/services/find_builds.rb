require 'core_ext/active_record/none_scope'
# v2 builds.all
#   build => commit, request, matrix.id

module Travis
  module Services
    class FindBuilds < Base
      register :find_builds

      def run
        preload(result)
      end

      def updated_at
        result.maximum(:updated_at)
      end

      private

        def result
          @result ||= params[:ids] ? by_ids : by_params
        end

        def by_ids
          scope(:build).where(:id => params[:ids])
        end

        def by_params
          if repo
            # TODO :after_number seems like a bizarre api why not just pass an id? pagination style?
            builds = repo.builds.recent
            builds = builds.by_event_type(params[:event_type])     if params[:event_type]
            builds = builds.limit(params[:limit].to_i)             if params[:limit].to_i.between? 1, 100
            builds = builds.where(:number => params[:number].to_s) if params[:number]
            builds = builds.older_than(params[:after_number])      if params[:after_number]
            builds = builds.on_state(params[:state])               if params[:state]
            builds
          else
            scope(:build).none
          end
        end

        def preload(builds)
          builds = builds.includes(:commit)
          # TODO rescue MissingAttribute in simple_states so we can stop loading :state
          ActiveRecord::Associations::Preloader.new(builds, :request, :select => [:id, :event_type, :state]).run
          ActiveRecord::Associations::Preloader.new(builds, :matrix, :select => [:id, :source_id, :state]).run
          builds
        end

        def repo
          @repo ||= run_service(:find_repo, params)
        end
    end
  end
end
