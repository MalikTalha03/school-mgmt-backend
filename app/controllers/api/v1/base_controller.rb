class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def require_roles(*roles)
    return if current_user && roles.map(&:to_s).include?(current_user.role)

    render json: { error: "Forbidden: insufficient permissions" }, status: :forbidden
  end

  def admin?
    current_user&.admin?
  end

  def student?
    current_user&.student?
  end

  def teacher?
    current_user&.teacher?
  end
end
