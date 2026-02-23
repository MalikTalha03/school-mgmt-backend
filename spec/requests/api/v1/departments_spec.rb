require 'rails_helper'

RSpec.describe 'Api::V1::Departments', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:department) { create(:department, name: 'Computer Science', code: 'CS') }
  let(:valid_attributes) { { name: 'Software Engineering', code: 'SE' } }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/departments' do
    it 'returns all departments with associations' do
      get '/api/v1/departments', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
      expect(json.first).to have_key('name')
      expect(json.first).to have_key('code')
    end

    it 'requires authentication' do
      get '/api/v1/departments'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/departments/:id' do
    it 'returns the department with details' do
      get "/api/v1/departments/#{department.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(department.id)
      expect(json['name']).to eq('Computer Science')
      expect(json['code']).to eq('CS')
    end

    it 'includes students, teachers, and courses' do
      teacher = create(:teacher, department: department)
      student = create(:student, department: department)
      course = create(:course, department: department, teacher: teacher, credit_hours: 3)

      get "/api/v1/departments/#{department.id}", headers: { 'Authorization' => @token }

      json = JSON.parse(response.body)
      expect(json).to have_key('students')
      expect(json).to have_key('teachers')
      expect(json).to have_key('courses')
    end

    it 'returns 404 when department not found' do
      get '/api/v1/departments/999999', headers: { 'Authorization' => @token }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/departments' do
    context 'with valid parameters' do
      it 'creates a new department' do
        expect {
          post '/api/v1/departments',
               params: { department: valid_attributes },
               headers: { 'Authorization' => @token }
        }.to change(Department, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Software Engineering')
        expect(json['code']).to eq('SE')
      end
    end

    context 'code normalization' do
      it 'converts code to uppercase' do
        post '/api/v1/departments',
             params: { department: valid_attributes.merge(code: 'se') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('SE')
      end
    end

    context 'name validation' do
      it 'requires a name' do
        post '/api/v1/departments',
             params: { department: valid_attributes.merge(name: '') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'prevents duplicate names' do
        post '/api/v1/departments',
             params: { department: { name: 'Computer Science', code: 'CS2' } },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'code validation' do
      it 'requires a code' do
        post '/api/v1/departments',
             params: { department: valid_attributes.merge(code: '') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'prevents duplicate codes' do
        post '/api/v1/departments',
             params: { department: { name: 'New Department', code: 'CS' } },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/departments/:id' do
    it 'updates the department' do
      put "/api/v1/departments/#{department.id}",
          params: { department: { name: 'Computer & Information Sciences' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      department.reload
      expect(department.name).to eq('Computer & Information Sciences')
    end

    it 'normalizes code on update' do
      put "/api/v1/departments/#{department.id}",
          params: { department: { code: 'cis' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      department.reload
      expect(department.code).to eq('CIS')
    end

    it 'validates uniqueness on update' do
      other_dept = create(:department, name: 'Physics', code: 'PHY')

      put "/api/v1/departments/#{department.id}",
          params: { department: { code: 'PHY' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/departments/:id' do
    context 'without associations' do
      it 'deletes the department' do
        new_dept = create(:department, name: 'Mathematics', code: 'MATH')

        expect {
          delete "/api/v1/departments/#{new_dept.id}",
                 headers: { 'Authorization' => @token }
        }.to change(Department, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with students' do
      let!(:student) { create(:student, department: department) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/departments/#{department.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Department, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('students')
      end
    end

    context 'with teachers' do
      let!(:teacher) { create(:teacher, department: department) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/departments/#{department.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Department, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('teachers')
      end
    end

    context 'with courses' do
      let!(:teacher) { create(:teacher, department: department) }
      let!(:course) { create(:course, department: department, teacher: teacher, credit_hours: 3) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/departments/#{department.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Department, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('courses')
      end
    end
  end
end
