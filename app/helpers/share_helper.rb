module ShareHelper
  SHARE_TITLE = "NEET PG Choice Planner"
  SHARE_TEXT = "Plan your NEET PG choices calmly, then fill them on the MCC portal in minutes. Free and open source."

  def share_title = SHARE_TITLE

  def share_text = SHARE_TEXT

  def share_whatsapp_url = "https://wa.me/?text=#{ERB::Util.url_encode("#{SHARE_TEXT} #{root_url}")}"

  def share_telegram_url = "https://t.me/share/url?url=#{ERB::Util.url_encode(root_url)}&text=#{ERB::Util.url_encode(SHARE_TEXT)}"

  def extension_link_whatsapp_url = "https://wa.me/?text=#{ERB::Util.url_encode("Install the MCC filler on my computer: #{extension_url}")}"

  def extension_link_email_url = "mailto:?subject=#{ERB::Util.url_encode("Install the MCC filler on my computer")}&body=#{ERB::Util.url_encode("Open this in Chrome, Edge, Brave, Opera or Firefox on your laptop or desktop to install the MCC filler:\n\n#{extension_url}")}"

  def share_email_url = "mailto:?subject=#{ERB::Util.url_encode(SHARE_TITLE)}&body=#{ERB::Util.url_encode("#{SHARE_TEXT}\n\n#{root_url}")}"
end
