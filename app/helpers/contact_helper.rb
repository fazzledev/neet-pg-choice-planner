module ContactHelper
  CONTACT_PHONE = "+919940689619"
  CONTACT_PHONE_DISPLAY = "+91 99406 89619"
  CONTACT_EMAIL = "hey@fazzle.dev"

  def contact_phone_display = CONTACT_PHONE_DISPLAY

  def contact_email = CONTACT_EMAIL

  def contact_phone_url = "tel:#{CONTACT_PHONE}"

  def contact_whatsapp_url = "https://wa.me/#{CONTACT_PHONE.delete_prefix("+")}"
end
