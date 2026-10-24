Rails.application.routes.draw do
  constraints(host: /\A(mcc|neet-pg-choices)\.fazzle\.dev\z/) do
    match "(*path)", to: redirect { |_, request| "https://neet-pg-choice-planner.fazzle.dev#{request.fullpath}" }, via: %i[get head]
  end

  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  get "sign-in/:token" => "sessions#show", as: :sign_in_link
  post "sign-in/:token" => "sessions#consume"

  root "pages#home"
  get "plan" => "planner#show", as: :planner
  get "privacy" => "pages#privacy", as: :privacy
  resource :presence, only: :create
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  resources :lists, only: :show do
    member { get :export }
    resource :picks, only: %i[show update]
    resources :snapshots, only: :index do
      member { post :restore }
    end
  end

  resources :catalogs, only: :show do
    member { get :locations }
  end
  get "cutoffs" => "cutoffs#show", as: :cutoffs

  get ".well-known/oauth-protected-resource(/mcp)" => "oauth/metadata#protected_resource", as: :oauth_protected_resource
  get ".well-known/oauth-authorization-server" => "oauth/metadata#authorization_server", as: :oauth_authorization_server
  namespace :oauth do
    post "register" => "registrations#create", as: :registration
    get "authorize" => "authorizations#new", as: :authorization
    post "authorize" => "authorizations#create"
    post "token" => "tokens#create", as: :token
  end
  post "mcp" => "mcp#create", as: :mcp
  match "mcp" => "mcp#not_allowed", via: %i[get delete]
  get "connect" => "connections#index", as: :connect
  resources :connections, only: :destroy

  get "practice" => "practice#show", as: :practice
  resource :extension, only: :show do
    get :download
  end

  namespace :admin do
    resources :users, only: %i[index create] do
      member { post :invite }
    end
    resource :stats, only: :show
  end
end
