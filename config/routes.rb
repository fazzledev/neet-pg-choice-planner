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
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  resources :lists, only: :show do
    member { get :export }
    resource :picks, only: %i[show update]
    resources :snapshots, only: :index do
      member { post :restore }
    end
  end

  resources :catalogs, only: :show

  resource :extension, only: :show do
    get :download
  end

  namespace :admin do
    resources :users, only: %i[index create] do
      member { post :invite }
    end
  end
end
