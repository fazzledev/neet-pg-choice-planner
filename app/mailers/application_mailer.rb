class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("SMTP_FROM", "NEET PG Choice Planner <hey@fazzle.dev>") }
  layout "mailer"
end
