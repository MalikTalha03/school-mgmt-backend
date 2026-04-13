require 'rails_helper'

RSpec.describe 'Api::V1::Teachers', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:teacher_user) { create(:user, role: :teacher, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:teacher) { create(:teacher, user: teacher_user, department: department, designation: :associate_professor) }
  let(:valid_attributes) { { name: 'New Teacher', department_id: department.id, designation: 'assistant_professor' } }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/teachers' do
    it 'returns all teachers' do
      get '/api/v1/teachers', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
    end

    it 'requires authentication' do
      get '/api/v1/teachers', headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/teachers/:id' do
    it 'returns the teacher with courses' do
      course = create(:course, teacher: teacher, department: department, credit_hours: 3)

      get "/api/v1/teachers/#{teacher.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(teacher.id)
      expect(json['designation']).to eq('associate_professor')
      expect(json).to have_key('courses')
    end

    it 'returns 404 when teacher not found' do
      get '/api/v1/teachers/999999', headers: { 'Authorization' => @token }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/teachers' do
    context 'with valid parameters' do
      it 'creates a new teacher' do
        expect {
          post '/api/v1/teachers',
               params: { teacher: valid_attributes },
               headers: { 'Authorization' => @token }
        }.to change(Teacher, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['designation']).to eq('assistant_professor')
      end
    end

    context 'designation validation' do
      it 'accepts valid designations' do
        %w[visiting_faculty lecturer assistant_professor associate_professor professor].each do |designation|
          post '/api/v1/teachers',
               params: { teacher: { name: "Teacher #{designation}", department_id: department.id, designation: designation } },
               headers: { 'Authorization' => @token }

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['designation']).to eq(designation)
        end
      end

      it 'rejects invalid designations' do
        post '/api/v1/teachers',
             params: { teacher: valid_attributes.merge(designation: 'invalid_designation') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'name validation' do
      it 'requires name' do
        post '/api/v1/teachers',
             params: { teacher: valid_attributes.merge(name: '') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/teachers/:id' do
    it 'updates the teacher' do
      put "/api/v1/teachers/#{teacher.id}",
          params: { teacher: { designation: 'professor' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      teacher.reload
      expect(teacher.designation).to eq('professor')
    end

    it 'validates designation on update' do
      put "/api/v1/teachers/#{teacher.id}",
          params: { teacher: { designation: 'invalid' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/teachers/:id' do
    context 'without courses' do
      it 'deletes the teacher' do
        new_teacher = create(:teacher, department: department)

        expect {
          delete "/api/v1/teachers/#{new_teacher.id}",
                 headers: { 'Authorization' => @token }
        }.to change(Teacher, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with courses' do
      let!(:course) { create(:course, teacher: teacher, department: department, credit_hours: 3) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/teachers/#{teacher.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Teacher, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('courses')
      end
    end
  end

  describe 'Course limits' do
    it 'allows teacher with less than 3 courses' do
      2.times do |i|
        create(:course, title: "Course #{i}", teacher: teacher, department: department, credit_hours: 3)
      end

      get "/api/v1/teachers/#{teacher.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['courses'].count).to eq(2)
    end
  end
end
