require 'rails_helper'

RSpec.describe 'Api::V1::Students', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:student_user) { create(:user, role: :student, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:student) { create(:student, user: student_user, department: department, semester: 3, max_credit_per_semester: 21) }
  let(:valid_attributes) { { name: 'New Student', department_id: department.id, semester: 2 } }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/students' do
    it 'returns all students' do
      get '/api/v1/students', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
    end

    it 'requires authentication' do
      get '/api/v1/students', headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/students/:id' do
    it 'returns the student' do
      get "/api/v1/students/#{student.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(student.id)
      expect(json['semester']).to eq(3)
    end

    it 'returns 404 when student not found' do
      get '/api/v1/students/999999', headers: { 'Authorization' => @token }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/students' do
    context 'with valid parameters' do
      it 'creates a new student' do
        expect {
          post '/api/v1/students',
               params: { student: valid_attributes },
               headers: { 'Authorization' => @token }
        }.to change(Student, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['semester']).to eq(2)
      end
    end

    context 'semester validation' do
      it 'rejects semester greater than 12' do
        post '/api/v1/students',
             params: { student: valid_attributes.merge(semester: 13) },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Semester must be between 1 and 12')
      end

      it 'rejects semester 0 or negative' do
        post '/api/v1/students',
             params: { student: valid_attributes.merge(semester: 0) },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'name validation' do
      it 'requires name' do
        post '/api/v1/students',
             params: { student: valid_attributes.merge(name: '') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Name is required')
      end
    end
  end

  describe 'PUT /api/v1/students/:id' do
    it 'updates the student' do
      put "/api/v1/students/#{student.id}",
          params: { student: { semester: 4 } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      student.reload
      expect(student.semester).to eq(4)
    end

    it 'validates semester on update' do
      put "/api/v1/students/#{student.id}",
          params: { student: { semester: 15 } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/students/:id' do
    it 'deletes the student' do
      new_student = create(:student, department: department)

      expect {
        delete "/api/v1/students/#{new_student.id}",
               headers: { 'Authorization' => @token }
      }.to change(Student, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
