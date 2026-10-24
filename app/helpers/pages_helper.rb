module PagesHelper
  PortalVsPlanner = Data.define(:portal_icon, :portal_title, :portal_text, :planner_icon, :planner_title, :planner_text)

  PORTAL_VS_PLANNER = [
    PortalVsPlanner.new("rows-3", "Thousands of rows", "One table of every choice, with a single text box to filter it.",
      "search", "Find seats fast", "Search by college, city or speciality, and filter by course, state, institute type and quota."),
    PortalVsPlanner.new("arrow-up-down", "One row per click", "Up and Down arrows move a choice one place at a time.",
      "grip-vertical", "Drag to rank", "Drag a choice, or type the rank you want. Gather a college's seats together."),
    PortalVsPlanner.new("list", "One flat list", "No way to see your list by college or by speciality.",
      "layers", "Group the way you think", "See the catalog and your plan by institute or by speciality, side by side."),
    PortalVsPlanner.new("triangle-alert", "Crashes at peak hours", "In Round 1, students lost hours waiting for the page to load.",
      "wifi-off", "Plan offline", "Your plan saves in your browser. Copy it to MCC in minutes once the portal is up."),
    PortalVsPlanner.new("calendar-x", "Opens only in rounds", "You can't start your list until choice filling opens.",
      "cloud", "Plan ahead, anywhere", "Start before the round opens. Sign in to use it on phone and laptop, with a history you can restore."),
    PortalVsPlanner.new("file-question", "No closing ranks", "Past allotments sit in separate PDFs, round by round.",
      "trending-up", "See past closing ranks", "2023–2025, round by round, for Open and your category, on most seats."),
    PortalVsPlanner.new("circle-question-mark", "No sense of your odds", "Nothing tells you which seats are within reach of your rank.",
      "target", "Know your chances", "Enter your rank and category to see Likely, Possible, Borderline or Reach."),
    PortalVsPlanner.new("phone-off", "No DNB contacts", "Asking about stipend or bond means hunting for a number yourself.",
      "phone", "Ask before you choose", "Where a DNB hospital lists a coordinator, their contact sits next to the seat.")
  ].freeze

  def portal_vs_planner
    PORTAL_VS_PLANNER
  end
end
