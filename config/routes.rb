Rails.application.routes.draw do
  # config/routes.rb
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  namespace :api do
    namespace :v1 do
      resources :departments
      resources :students
      resources :teachers
      resources :courses
      resources :enrollments
      resources :grades
      resources :grade_items
    end
  end
end
