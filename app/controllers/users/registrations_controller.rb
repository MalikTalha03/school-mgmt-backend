class Users::RegistrationsController < Devise::RegistrationsController
  # POST /signup
  def create
    # Only allow student or teacher roles
    if params[:user][:role].present? && ![ "student", "teacher" ].include?(params[:user][:role])
      return render json: { error: "Invalid role" }, status: :forbidden
    end

    super
  end
end
