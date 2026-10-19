Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  get "sign-in/:token" => "sessions#show", as: :sign_in_link
  post "sign-in/:token" => "sessions#consume"

  root "planner#show"
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
