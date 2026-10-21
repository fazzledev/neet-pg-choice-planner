ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "turbo/broadcastable/test_helper"

module ActiveSupport
  class TestCase
    include Turbo::Broadcastable::TestHelper

    parallelize(workers: :number_of_processors)

    def import_catalog
      CatalogImport.new(file_fixture("catalog.json"), name: "NEET PG 2026", slug: "neet-pg-2026").run
    end
  end
end

module SignInHelper
  def sign_in_as(user)
    post sign_in_link_path(user.generate_token_for(:sign_in))
    assert_redirected_to planner_url
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
