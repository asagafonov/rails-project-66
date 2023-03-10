# frozen_string_literal: true

require 'test_helper'

class UpdateRepositoryJobTest < ActiveJob::TestCase
  setup do
    @repo = repositories(:react)
  end

  test 'update repository job fires' do
    UpdateRepositoryJob.perform_later(@repo.id)

    assert_enqueued_with(
      job: UpdateRepositoryJob,
      args: [@repo.id],
      queue: 'default'
    )
  end
end
