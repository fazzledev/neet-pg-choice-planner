require "application_system_test_case"

class PresenceSystemTest < ApplicationSystemTestCase
  setup { import_catalog }

  test "an open page reports itself present and keeps one row across navigation" do
    with_forgery_protection do
      visit root_path
      first_seen = eventually { Presence.first&.last_seen_at }

      visit privacy_path
      eventually { Presence.sole.last_seen_at > first_seen }

      assert_equal 1, Presence.count
    end
  end

  private

  def eventually
    Timeout.timeout(5) do
      loop do
        result = yield
        return result if result
        sleep 0.1
      end
    end
  end
end
