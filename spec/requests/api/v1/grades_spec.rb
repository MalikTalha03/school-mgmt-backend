require 'rails_helper'

RSpec.describe 'Api::V1::Grades', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:student) { create(:student, department: department) }
  let!(:teacher) { create(:teacher, department: department) }
  let!(:course) { create(:course, teacher: teacher, department: department, credit_hours: 3) }
  let!(:enrollment) { create(:enrollment, student: student, course: course, status: :enrolled) }
  let!(:grade) { create(:grade, student: student, course: course) }
  
  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/grades' do
    it 'returns all grades with grade items' do
      get '/api/v1/grades', headers: { 'Authorization' => @token }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
    end
  end

  describe 'GET /api/v1/grades/:id' do
    it 'returns the grade with details' do
      get "/api/v1/grades/#{grade.id}", headers: { 'Authorization' => @token }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(grade.id)
    end
  end

  describe 'POST /api/v1/grades' do
    context 'with valid enrollment' do
      it 'creates a new grade' do
        new_student = create(:student, department: department)
        new_course = create(:course, teacher: teacher, department: department, credit_hours: 3)
        create(:enrollment, student: new_student, course: new_course, status: :enrolled)
        
        expect {
          post '/api/v1/grades',
               params: { grade: { student_id: new_student.id, course_id: new_course.id } },
               headers: { 'Authorization' => @token }
        }.to change(Grade, :count).by(1)
        
        expect(response).to have_http_status(:created)
      end
    end

    context 'without enrollment' do
      it 'rejects grade creation' do
        random_student = create(:student, department: department)
        random_course = create(:course, teacher: teacher, department: department, credit_hours: 3)
        
        post '/api/v1/grades',
             params: { grade: { student_id: random_student.id, course_id: random_course.id } },
             headers: { 'Authorization' => @token }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('without active enrollment')
      end
    end

    context 'duplicate grade' do
      it 'prevents duplicate grade records' do
        post '/api/v1/grades',
             params: { grade: { student_id: student.id, course_id: course.id } },
             headers: { 'Authorization' => @token }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('already exists')
      end
    end
  end

  describe 'DELETE /api/v1/grades/:id' do
    it 'deletes the grade' do
      new_grade = create(:grade, student: create(:student, department: department), course: create(:course, teacher: teacher, department: department, credit_hours: 3))
      
      expect {
        delete "/api/v1/grades/#{new_grade.id}",
               headers: { 'Authorization' => @token }
      }.to change(Grade, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end
end
