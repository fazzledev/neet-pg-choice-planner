if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"] != "1"
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: 587,
    domain: ENV.fetch("SMTP_DOMAIN"),
    user_name: ENV.fetch("SMTP_USER_NAME"),
    password: Rails.application.credentials.dig(:smtp, :password),
    authentication: :plain,
    enable_starttls_auto: true,
    open_timeout: 15,
    read_timeout: 20
  }
end
