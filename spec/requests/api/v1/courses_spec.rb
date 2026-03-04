require 'rails_helper'

RSpec.describe 'Api::V1::Courses', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:teacher) { create(:teacher, department: department) }
  let!(:course) { create(:course, title: 'Data Structures', credit_hours: 3, teacher: teacher, department: department) }
  let(:valid_attributes) { { title: 'Algorithms', credit_hours: 3, teacher_id: teacher.id, department_id: department.id } }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/courses' do
    it 'returns all courses with associations' do
      get '/api/v1/courses', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
      expect(json.first).to have_key('teacher')
      expect(json.first).to have_key('department')
    end

    it 'requires authentication' do
      get '/api/v1/courses', headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/courses/:id' do
    it 'returns the course' do
      get "/api/v1/courses/#{course.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(course.id)
      expect(json['title']).to eq('Data Structures')
    end

    it 'returns 404 when course not found' do
      get '/api/v1/courses/999999', headers: { 'Authorization' => @token }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/courses' do
    context 'with valid parameters' do
      it 'creates a new course' do
        expect {
          post '/api/v1/courses',
               params: { course: valid_attributes },
               headers: { 'Authorization' => @token }
        }.to change(Course, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('Algorithms')
        expect(json['credit_hours']).to eq(3)
      end
    end

    context 'credit hours validation' do
      it 'rejects credit_hours greater than 4' do
        post '/api/v1/courses',
             params: { course: valid_attributes.merge(credit_hours: 5) },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Credit hours must be between 0 and 4')
      end

      it 'rejects negative credit_hours' do
        post '/api/v1/courses',
             params: { course: valid_attributes.merge(credit_hours: -1) },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'teacher limit validation' do
      before do
        # One course already exists for this teacher via let!(:course)
        2.times do |i|
          create(:course, title: "Course #{i}", teacher: teacher, department: department, credit_hours: 3)
        end
      end

      it 'prevents teacher from having more than 3 courses' do
        post '/api/v1/courses',
             params: { course: valid_attributes },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('maximum 3 courses assigned')
      end
    end

    context 'title validation' do
      it 'requires a title' do
        post '/api/v1/courses',
             params: { course: valid_attributes.merge(title: '') },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/courses/:id' do
    it 'updates the course' do
      put "/api/v1/courses/#{course.id}",
          params: { course: { title: 'Advanced Data Structures' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      course.reload
      expect(course.title).to eq('Advanced Data Structures')
    end

    it 'validates credit_hours on update' do
      put "/api/v1/courses/#{course.id}",
          params: { course: { credit_hours: 10 } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'validates teacher limit on teacher change' do
      busy_teacher = create(:teacher, department: department)
      3.times do |i|
        create(:course, title: "Course #{i}", teacher: busy_teacher, department: department, credit_hours: 3)
      end

      put "/api/v1/courses/#{course.id}",
          params: { course: { teacher_id: busy_teacher.id } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('maximum 3 courses assigned')
    end
  end

  describe 'DELETE /api/v1/courses/:id' do
    context 'without enrollments or grades' do
      it 'deletes the course' do
        new_course = create(:course, teacher: teacher, department: department, credit_hours: 3)

        expect {
          delete "/api/v1/courses/#{new_course.id}",
                 headers: { 'Authorization' => @token }
        }.to change(Course, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with enrollments' do
      let!(:student) { create(:student, department: department) }
      let!(:enrollment) { create(:enrollment, student: student, course: course, status: :approved) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/courses/#{course.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Course, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('active enrollments')
      end
    end

    context 'with grades' do
      let!(:student) { create(:student, department: department) }
      let!(:grade) { create(:grade, student: student, course: course) }

      it 'prevents deletion' do
        expect {
          delete "/api/v1/courses/#{course.id}",
                 headers: { 'Authorization' => @token }
        }.not_to change(Course, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('existing grade records')
      end
    end
  end
end
