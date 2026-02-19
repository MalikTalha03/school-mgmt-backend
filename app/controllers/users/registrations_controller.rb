# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, only: [:create]

  # POST /signup
  def create
    # Only allow student or teacher roles
    if params[:user][:role].present? && !["student", "teacher"].include?(params[:user][:role])
      return render json: { error: "Invalid role" }, status: :forbidden
    end

    super
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
  end
end
