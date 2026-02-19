Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow React dev server (Vite runs on 5173) and other local origins
    origins '*'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization'], # Expose JWT token header to frontend
      max_age: 600
  end
end
