require 'rails_helper'

RSpec.describe 'Api::V1::Enrollments', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:student) { create(:student, department: department, semester: 3, max_credit_per_semester: 21) }
  let!(:teacher) { create(:teacher, department: department) }
  let!(:course) { create(:course, title: 'Web Dev', credit_hours: 3, teacher: teacher, department: department) }
  let!(:enrollment) { create(:enrollment, student: student, course: course, status: :approved) }
  let(:valid_attributes) { { student_id: create(:student, department: department).id, course_id: create(:course, teacher: teacher, department: department, credit_hours: 3).id, status: 'approved' } }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/enrollments' do
    it 'returns all enrollments with associations' do
      get '/api/v1/enrollments', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
    end
  end

  describe 'GET /api/v1/enrollments/:id' do
    it 'returns the enrollment' do
      get "/api/v1/enrollments/#{enrollment.id}", headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(enrollment.id)
    end
  end

  describe 'POST /api/v1/enrollments' do
    context 'with valid parameters' do
      it 'creates a new enrollment' do
        new_student = create(:student, department: department, semester: 2)
        new_course = create(:course, teacher: teacher, department: department, credit_hours: 3)

        expect {
          post '/api/v1/enrollments',
           params: { enrollment: { student_id: new_student.id, course_id: new_course.id, status: 'approved' } },
               headers: { 'Authorization' => @token }
        }.to change(Enrollment, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context 'credit hours limit validation' do
      before do
        # Existing enrollment contributes 3 approved credits; add 15 more
        5.times do |i|
          course_teacher = create(:teacher, department: department)
          course = create(:course, title: "Course #{i}", teacher: course_teacher, department: department, credit_hours: 3)
          create(:enrollment, student: student, course: course, status: :approved)
        end
      end

      it 'prevents enrollment exceeding 21 credit hours' do
        new_course = create(:course, title: 'Overflow Course', teacher: create(:teacher, department: department), department: department, credit_hours: 4)

        post '/api/v1/enrollments',
             params: { enrollment: { student_id: student.id, course_id: new_course.id, status: 'approved' } },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join(' ')).to include('exceed maximum credit hours')
      end
    end

    context 'semester limit validation' do
      let!(:expired_student) do
        student = create(:student, department: department, semester: 2)
        student.update_column(:semester, 13)
        student
      end

      it 'prevents enrollment for student exceeding semester 12' do
        new_course = create(:course, title: 'Test', teacher: teacher, department: department, credit_hours: 3)

        post '/api/v1/enrollments',
             params: { enrollment: { student_id: expired_student.id, course_id: new_course.id, status: 'approved' } },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
           expect(json['errors'].join(' ')).to include('maximum semester limit')
      end
    end

    context 'duplicate enrollment validation' do
      it 'prevents duplicate enrollment in same course' do
        post '/api/v1/enrollments',
             params: { enrollment: { student_id: student.id, course_id: course.id, status: 'approved' } },
             headers: { 'Authorization' => @token }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join(' ')).to include('already enrolled')
      end
    end
  end

  describe 'PUT /api/v1/enrollments/:id' do
    it 'updates enrollment status' do
      put "/api/v1/enrollments/#{enrollment.id}",
          params: { enrollment: { status: 'completed' } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      enrollment.reload
      expect(enrollment.status).to eq('completed')
    end

    it 'prevents changing student or course' do
      new_student = create(:student, department: department)

      put "/api/v1/enrollments/#{enrollment.id}",
          params: { enrollment: { student_id: new_student.id } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Cannot change student or course')
    end
  end
end
