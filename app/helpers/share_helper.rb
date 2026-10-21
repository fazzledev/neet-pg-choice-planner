module ShareHelper
  def share_data(event)
    {
      share_url: root_url,
      share_title: "NEET PG Choice Planner",
      share_text: "Plan your NEET PG choices calmly, then fill them on the MCC portal in minutes. Free and open source.",
      **click_event(event)
    }
  end
end
