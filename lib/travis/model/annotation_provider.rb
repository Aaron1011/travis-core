require "active_record"

class AnnotationProvider < ActiveRecord::Base
  has_many :annotations

  serialize :api_key, Travis::Model::EncryptedColumn.new

  def self.authenticate_provider(username, key)
    provider = where(api_username: username).first

    provider && provider.api_key == key ? provider : nil
  end

  def annotation_for_job(job_id)
    annotations.where(job_id: job_id).first || annotations.build(job_id: job_id)
  end
end
