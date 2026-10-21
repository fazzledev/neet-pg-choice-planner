CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Tests: Rails", "bin/rails test"
  step "Tests: System", "bin/rails test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

end
