class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in) if is_flashing_format?
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with(resource, location: after_sign_in_path_for(resource))
  end

  private

  def respond_with(resource, _opts = {})
    render json: {
      message: "Logged in successfully",
      user: {
        id: resource.id,
        email: resource.email,
        role: resource.role
      }
    }, status: :ok
  end

  def respond_to_on_destroy(_opts = {})
    if request.headers["Authorization"].present?
      begin
        jwt_payload = JWT.decode(request.headers["Authorization"].split(" ").last,
                                 Rails.application.credentials.devise_jwt_secret_key).first
        current_user = User.find(jwt_payload["sub"])
      rescue JWT::DecodeError
        current_user = nil
      end
    end

    if current_user
      render json: {
        message: "Logged out successfully."
      }, status: :ok
    else
      render json: {
        message: "No active session."
      }, status: :unauthorized
    end
  end

  def set_flash_message!(key, kind, options = {})
    # Override to prevent flash usage in API-only mode
  end
end
