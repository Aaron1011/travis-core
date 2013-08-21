require 'active_record'
require 'core_ext/active_record/base'
require 'core_ext/hash/deep_symbolize_keys'
require 'simple_states'

# Build currently models a central but rather abstract domain entity: the thing
# that is triggered by a Github request (service hook ping).
#
# Build groups a matrix of Job::Test instances, and belongs to a Request (and
# thus Commit as well as a Repository).
#
# A Build is created when its Request was configured (by fetching .travis.yml)
# and approved (e.g. not excluded by the configuration). Once a Build is
# created it will expand its matrix according to the given configuration and
# create the according Job::Test instances.  Each Job::Test instance will
# trigger a test run remotely (on the worker). Once all Job::Test instances
# have finished the Build will be finished as well.
#
# Each of these state changes (build:created, job:started, job:finished, ...)
# will issue events that are listened for by the event handlers contained in
# travis/notification. These event handlers then send out various notifications
# of various types through email, pusher and irc, archive builds and queue
# jobs for the workers.
#
# Build is split up to several modules:
#
#  * Build       - ActiveRecord structure, validations and scopes
#  * States      - state definitions and events
#  * Denormalize - some state changes denormalize attributes to the build's
#                  repository (e.g. Build#started_at gets propagated to
#                  Repository#last_started_at)
#  * Matrix      - logic related to expanding the build matrix, normalizing
#                  configuration for Job::Test instances, evaluating the
#                  final build result etc.
#  * Messages    - helpers for evaluating human readable result messages
#                  (e.g. "Still Failing")
#  * Events      - helpers that are used by notification handlers (and that
#                  TODO probably should be cleaned up and moved to
#                  travis/notification)
class Build < ActiveRecord::Base
  autoload :Denormalize,   'travis/model/build/denormalize'
  autoload :Matrix,        'travis/model/build/matrix'
  autoload :Metrics,       'travis/model/build/metrics'
  autoload :ResultMessage, 'travis/model/build/result_message'
  autoload :States,        'travis/model/build/states'

  include Matrix, States, SimpleStates
  include Travis::Model::EnvHelpers

  belongs_to :commit
  belongs_to :request
  belongs_to :repository, autosave: true
  belongs_to :owner, polymorphic: true
  has_many   :matrix, as: :source, order: :id, class_name: 'Job::Test', dependent: :destroy
  has_many   :events, as: :source

  validates :repository_id, :commit_id, :request_id, presence: true

  serialize :config

  delegate :same_repo_pull_request?, :to => :request

  class << self
    def recent(options = {})
      where('state IN (?)', state_names - [:created, :queued]).order(arel_table[:started_at].desc).paged(options)
    end

    def was_started
      where('state <> ?', :created)
    end

    def finished
      where(state: [:finished, :passed, :failed, :errored, :canceled]) # TODO extract
    end

    def on_state(state)
      where(state.present? ? ['builds.state IN (?)', state] : [])
    end

    def on_branch(branch)
      if Build.column_names.include?('branch')
        pushes.where(branch.present? ? ['branch IN (?)', normalize_to_array(branch)] : [])
      else
        pushes.joins(:commit).where(branch.present? ? ['commits.branch IN (?)', normalize_to_array(branch)] : [])
      end
    end

    def by_event_type(event_type)
      event_type == 'pull_request' ?  pull_requests : pushes
    end

    def pushes
      where(:event_type => 'push')
    end

    def pull_requests
      where(event_type: 'pull_request')
    end

    def previous(build)
      where('builds.repository_id = ? AND builds.id < ?', build.repository_id, build.id).finished.descending.limit(1).first
    end

    def descending
      order(arel_table[:id].desc)
    end

    def paged(options)
      page = (options[:page] || 1).to_i
      limit(per_page).offset(per_page * (page - 1))
    end

    def last_build_on(options)
      scope = descending
      scope = scope.on_state(options[:state])   if options[:state]
      scope = scope.on_branch(options[:branch]) if options[:branch]
      scope.first
    end

    def last_state_on(options)
      last_build_on(options).try(:state).try(:to_sym)
    end

    def older_than(build = nil)
      scope = descending.paged({}) # TODO in which case we'd call older_than without an argument?
      scope = scope.where('number::integer < ?', (build.is_a?(Build) ? build.number : build).to_i) if build
      scope
    end

    def next_number
      maximum(floor('number')).to_i + 1
    end

    protected

      def normalize_to_array(object)
        Array(object).compact.join(',').split(',')
      end

      def per_page
        25
      end
  end

  after_initialize do
    self.config = {} if config.nil?
  end

  # set the build number and expand the matrix
  before_create do
    self.number = repository.builds.next_number
    self.previous_state = last_finished_state_on_branch
    self.event_type = request.event_type
    self.pull_request_title = request.pull_request_title
    self.pull_request_number = request.pull_request_number
    self.branch = commit.branch if Build.column_names.include?('branch')
    expand_matrix
  end

  def matrix_ids
    matrix.map(&:id)
  end

  def secure_env_enabled?
    !pull_request? || same_repo_pull_request? || secure_pull_request?
  end
  alias addons_enabled? secure_env_enabled?

  # sometimes the config is not deserialized and is returned
  # as a string, this is a work around for now :(
  def config
    deserialized = self['config']
    if deserialized.is_a?(String)
      logger.warn "Attribute config isn't YAML. Current serialized attributes: #{Build.serialized_attributes}"
      deserialized = YAML.load(deserialized)
    end
    deserialized
  rescue Psych::SyntaxError => e
    logger.warn "[build id:#{id}] Config could not be deserialized due to #{e.message}"
    {}
  end

  def config=(config)
    super(config ? normalize_config(config) : {})
  end

  def obfuscated_config
    config.dup.tap do |config|
      config.delete(:source_key)
      next unless config[:env]
      config[:env] = [config[:env]] unless config[:env].is_a?(Array)
      if config[:env]
        config[:env] = config[:env].map do |env|
          env = normalize_env_hashes(env)
          obfuscate_env(env).join(' ')
        end
      end
    end
  end

  def normalize_env_hashes(lines)
    if Travis::Features.feature_active?(:global_env_in_config)
      process_line = ->(line) do
        if line.is_a?(Hash)
          env_hash_to_string(line)
        elsif line.is_a?(Array)
          line.map do |line|
            env_hash_to_string(line)
          end
        else
          line
        end
      end


      if lines.is_a?(Array)
        lines.map { |env| process_line.(env) }
      else
        process_line.(lines)
      end
    else
      # TODO: remove this branch when all workers are capable of handling global env
      if lines.is_a?(Hash)
        env_hash_to_string(lines)
      elsif lines.is_a?(Array)
        lines.map do |line|
          env_hash_to_string(line)
        end
      else
        lines
      end
    end
  end

  def env_hash_to_string(hash)
    return hash unless hash.is_a?(Hash)
    return hash if hash.has_key?(:secure)

    hash.map { |k,v| "#{k}=#{v}" }.join(' ')
  end

  def cancelable?
    matrix.any? { |job| job.cancelable? }
  end

  def pull_request?
    request.pull_request?
  end

  # COMPAT: used in http api v1, deprecate as soon as v1 gets retired
  def result
    state.try(:to_sym) == :passed ? 0 : 1
  end

  private

    def normalize_env_values(values)
      if Travis::Features.feature_active?(:global_env_in_config)
        env = values
        global = nil

        if env.is_a?(Hash) && (env[:global] || env[:matrix])
          global = env[:global]
          env    = env[:matrix]
        end

        if env
          env = [env] unless env.is_a?(Array)
          env = normalize_env_hashes(env)
        end

        if global
          global = [global] unless global.is_a?(Array)
          global = normalize_env_hashes(global)
        end

        { env: env, global: global }
      else
        # TODO: remove this branch when all workers are capable of handling global env
        global = nil

        if values.is_a?(Hash) && (values[:global] || values[:matrix])
          global = values[:global]
          values = values[:matrix]
        end

        result = if global
          global = [global] unless global.is_a?(Array)

          values = [values] unless values.is_a?(Array)
          values.map do |line|
            line = [line] unless line.is_a?(Array)
            (line + global).compact
          end
        else
          values
        end

        env = if result.is_a?(Array)
          result.map { |env| normalize_env_hashes(env) }
        else
          normalize_env_hashes(result)
        end

        if global
          global = global.map { |env| normalize_env_hashes(env) }
        end

        { env: env, global: global }
      end
    end


    def normalize_config(config)
      config = config.deep_symbolize_keys
      if config[:env]
        result = normalize_env_values(config[:env])
        if result[:env]
          config[:env] = result[:env]
        else
          config.delete(:env)
        end

        key = Travis::Features.feature_active?(:global_env_in_config) ? :global_env : :_global_env
        config[key] = result[:global] if result[:global]
      end
      config
    end

    def last_finished_state_on_branch
      repository.builds.finished.last_state_on(branch: commit.branch)
    end
end
