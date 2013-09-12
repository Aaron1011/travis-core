module Travis
  module Services
    class FindBuild < Base
      register :find_build

      ALLOWED_PARAMS = [:id, :request_id, :repository_id, :owner_id, :commit_id, :pull_request_number]

      def run(options = {})
        preload(result) if result
      end

      def final?
        # TODO builds can be requeued, so finished builds are no more final
        # result.try(:finished?)
        false
      end

      def updated_at
        max = all_resources.max_by(&:updated_at)
        max.updated_at if max.respond_to?(:updated_at)
      end

      private

        def all_resources
          if result
            all = [result, result.commit, result.request, result.matrix.to_a]
            all.flatten.find_all { |r| r.updated_at }
          else
            []
          end
        end

        def result
          @result ||= scope(:build).where(params.select { |k| ALLOWED_PARAMS.include? k.to_sym } ).first
        end

        def preload(build)
          ActiveRecord::Associations::Preloader.new(build, [:commit, :request, :matrix]).run
          ActiveRecord::Associations::Preloader.new(build.matrix, :log, :select => [:id, :job_id, :updated_at]).run
          build
        end
    end
  end
end
