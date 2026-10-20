require "test_helper"

class CutoffsTest < ActionDispatch::IntegrationTest
  test "serves closing ranks publicly with caching" do
    get cutoffs_path
    assert_response :success
    assert_kind_of Hash, response.parsed_body
    assert_match "public", response.headers["Cache-Control"]

    get cutoffs_path, headers: { "If-None-Match" => response.headers["ETag"] }
    assert_response :not_modified
  end
end
