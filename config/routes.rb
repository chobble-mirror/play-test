Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest

  root "home#index"
  get "about", to: "home#about"
  get "safety_standards", to: "safety_standards#index"
  post "safety_standards", to: "safety_standards#index"

  get "signup", to: "users#new"
  post "signup", to: "users#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Users management (full CRUD)
  resources :users do
    member do
      get "change_password"
      patch "update_password"
      get "change_settings"
      patch "update_settings"
      post "impersonate"
      post "verify_rpii"
      post "add_seeds"
      delete "delete_seeds"
    end
  end

  # Inspections
  resources :inspections, except: [:new] do
    member do
      get "select_unit"
      patch "update_unit"
      patch "complete"
      patch "mark_draft"
      get "unified_edit"
      patch "unified_update"
    end

    resource :anchorage_assessment, only: [:update]
    resource :enclosed_assessment, only: [:update]
    resource :fan_assessment, only: [:update]
    resource :materials_assessment, only: [:update]
    resource :slide_assessment, only: [:update]
    resource :structure_assessment, only: [:update]
    resource :user_height_assessment, only: [:update]
  end

  # Units
  resources :units do
    member do
      get "unified_edit"
      patch "unified_update"
    end
  end

  # Create unit from inspection
  get "inspections/:id/new_unit", to: "units#new_from_inspection", as: "new_unit_from_inspection"
  post "inspections/:id/create_unit", to: "units#create_from_inspection", as: "create_unit_from_inspection"

  # Inspector Companies
  resources :inspector_companies, except: [:destroy]
end
