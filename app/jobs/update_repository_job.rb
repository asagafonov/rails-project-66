# frozen_string_literal: true

class UpdateRepositoryJob < ApplicationJob
  queue_as :default

  def perform(repository_id)
    repository = Repository.find(repository_id)

    repository.start_fetching!

    api = github_api(repository.user)

    data = api.fetch_repository_data(repository)
    api.create_hook(repository.github_id)

    repository.update(
      name: data[:name],
      full_name: data[:full_name],
      language: data[:language].downcase.to_sym,
      default_branch: data[:default_branch],
      clone_url: data[:clone_url],
      repo_created_at: data[:created_at],
      repo_updated_at: data[:updated_at]
    )

    repository.succeed!
  rescue StandardError
    repository.fail!
  end

  private

  def github_api(user)
    ApplicationContainer[:octokit].new(user)
  end
end
