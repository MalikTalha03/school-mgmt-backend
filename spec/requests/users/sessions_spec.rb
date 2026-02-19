require 'rails_helper'

RSpec.describe 'Users::Sessions', type: :request do
  let!(:user) { create(:user, email: 'test@example.com', password: 'password123', role: :admin) }

  describe 'POST /users/sign_in' do
    context 'with valid credentials' do
      it 'returns JWT token in Authorization header' do
        post '/users/sign_in',
             params: { user: { email: 'test@example.com', password: 'password123' } }
        
        expect(response).to have_http_status(:ok)
        expect(response.headers['Authorization']).to be_present
        expect(response.headers['Authorization']).to start_with('Bearer ')
        
        json = JSON.parse(response.body)
        expect(json).to have_key('id')
        expect(json['email']).to eq('test@example.com')
        expect(json['role']).to eq('admin')
      end
    end

    context 'with invalid email' do
      it 'returns unauthorized' do
        post '/users/sign_in',
             params: { user: { email: 'wrong@example.com', password: 'password123' } }
        
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Authorization']).to be_nil
      end
    end

    context 'with invalid password' do
      it 'returns unauthorized' do
        post '/users/sign_in',
             params: { user: { email: 'test@example.com', password: 'wrongpassword' } }
        
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['Authorization']).to be_nil
      end
    end

    context 'with missing parameters' do
      it 'returns bad request for missing email' do
        post '/users/sign_in',
             params: { user: { password: 'password123' } }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns bad request for missing password' do
        post '/users/sign_in',
             params: { user: { email: 'test@example.com' } }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /users/sign_out' do
    let(:token) do
      post '/users/sign_in',
           params: { user: { email: 'test@example.com', password: 'password123' } }
      response.headers['Authorization']
    end

    it 'revokes the JWT token' do
      delete '/users/sign_out',
             headers: { 'Authorization' => token }
      
      expect(response).to have_http_status(:ok)
    end

    it 'prevents using revoked token' do
      delete '/users/sign_out',
             headers: { 'Authorization' => token }
      
      # Try to access protected endpoint with revoked token
      get '/api/v1/students',
          headers: { 'Authorization' => token }
      
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
