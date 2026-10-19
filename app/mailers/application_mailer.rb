class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("SMTP_FROM", "Choice Planner <hey@fazzle.dev>") }
  layout "mailer"
end
