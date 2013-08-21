class AddSecurePullRequestToJobsAndBuilds < ActiveRecord::Migration
  def change
    add_column :jobs, :secure_pull_request, :boolean
    add_column :builds, :secure_pull_request, :boolean
  end
end
