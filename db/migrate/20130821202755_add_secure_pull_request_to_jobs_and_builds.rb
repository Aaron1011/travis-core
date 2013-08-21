class AddSecurePullRequestToJobsAndBuilds < ActiveRecord::Migration
  def change
    add_column :jobs, :force_secure_env, :boolean
    add_column :builds, :force_secure_env, :boolean
  end
end
