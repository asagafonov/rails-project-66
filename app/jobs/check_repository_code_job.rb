# frozen_string_literal: true

class CheckRepositoryCodeJob < ApplicationJob
  queue_as :default

  def perform(check_id)
    @repository_check = Repository::Check.find_by(id: check_id)
    repository = @repository_check.repository

    @repository_check.start_checking!

    git_clone(repository.clone_url)
    result = Linter.public_send("lint_#{repository.language}", directory)
    parsed_result = JsonParser.public_send("parse_#{repository.language}", result).reject(&:empty?)

    if parsed_result.empty?
      @repository_check.update(passed: true)
    else
      write_linter_errors(@repository_check, parsed_result)
      @repository_check.update(passed: false)
      UserMailer.with(user: repository.user, check: @repository_check).send_failed_email.deliver_now
    end
    @repository_check.finish!
  rescue StandardError
    UserMailer.with(user: repository.user, repo: repository).send_error_email.deliver_now
    @repository_check.update(passed: false)
    @repository_check.finish!
  end

  private

  def directory
    Rails.root.join('./tmp/repository_check')
  end

  def git_clone(url)
    clear_dir_command = "rm -rf #{directory}"
    Terminal.run_command(clear_dir_command)

    clone_command = "git clone #{url} #{directory}"
    Terminal.run_command(clone_command)
  end

  def write_linter_errors(check, errors)
    errors.each do |error|
      new_error = check.linter_errors.build(
        file_path: error[0][:file_path],
        message: error[0][:message],
        rule: error[0][:rule],
        location: error[0][:location]
      )

      new_error.save!
    end
  end
end
