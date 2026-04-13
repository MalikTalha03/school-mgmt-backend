Rails.application.routes.draw do
  # config/routes.rb
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  namespace :api do
    namespace :v1 do
      resources :departments
      resources :students do
        member do
          patch :promote_semester
        end
      end
      resources :teachers
      resources :courses
      resources :enrollments, except: [ :destroy ] do
        member do
          patch :approve
          patch :reject
          patch :complete
          patch :drop
          patch :withdraw
        end
        collection do
          post :request_enrollment
          post :announce_results
        end
      end
      resources :grades
      resources :grade_items
    end
  end
end
