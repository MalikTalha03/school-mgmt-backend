require 'rails_helper'

RSpec.describe 'Api::V1::GradeItems', type: :request do
  let!(:user) { create(:user, role: :admin, password: 'password123') }
  let!(:department) { create(:department) }
  let!(:student) { create(:student, department: department) }
  let!(:teacher) { create(:teacher, department: department) }
  let!(:course) { create(:course, teacher: teacher, department: department, credit_hours: 3) }
  let!(:enrollment) { create(:enrollment, student: student, course: course, status: :approved) }
  let!(:grade) { create(:grade, student: student, course: course) }
  let!(:assignment_1) { create(:grade_item, :assignment, grade: grade) }
  let!(:assignment_2) { create(:grade_item, :assignment, grade: grade) }
  let!(:quiz_1) { create(:grade_item, :quiz, grade: grade) }
  let!(:quiz_2) { create(:grade_item, :quiz, grade: grade) }
  let!(:midterm) { create(:grade_item, :midterm, grade: grade, max_marks: 30, obtained_marks: 25) }

  before do
    post '/users/sign_in', params: { user: { email: user.email, password: 'password123' } }
    @token = response.headers['Authorization']
  end

  describe 'GET /api/v1/grade_items' do
    it 'returns all grade items' do
      get '/api/v1/grade_items', headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
    end
  end

  describe 'POST /api/v1/grade_items' do
    it 'creates an assignment grade item' do
      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'assignment', max_marks: 20, obtained_marks: 18 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['category']).to eq('assignment')
    end

    it 'creates a quiz grade item' do
      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'quiz', max_marks: 20, obtained_marks: 15 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:created)
    end

    it 'rejects assignment with max_marks > 20' do
      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'assignment', max_marks: 25, obtained_marks: 20 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].join(' ')).to include('cannot exceed 20')
    end

    it 'rejects quiz with max_marks > 20' do
      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'quiz', max_marks: 30, obtained_marks: 20 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].join(' ')).to include('cannot exceed 20')
    end

    it 'allows final marks with all prerequisites' do
      create_list(:grade_item, 2, :assignment, grade: grade)
      create_list(:grade_item, 2, :quiz, grade: grade)

      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'final', max_marks: 50, obtained_marks: 45 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['category']).to eq('final')
    end

    it 'rejects final marks without midterm' do
      new_grade = create(:grade, student: create(:student, department: department), course: create(:course, teacher: teacher, department: department, credit_hours: 3))
      create_list(:grade_item, 4, :assignment, grade: new_grade)
      create_list(:grade_item, 4, :quiz, grade: new_grade)

      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: new_grade.id, category: 'final', max_marks: 100, obtained_marks: 80 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].join(' ')).to include('Cannot enter final marks')
    end

    it 'accepts final with max_marks 100' do
      create_list(:grade_item, 2, :assignment, grade: grade)
      create_list(:grade_item, 2, :quiz, grade: grade)

      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'final', max_marks: 100, obtained_marks: 85 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:created)
    end

    it 'rejects final with invalid max_marks' do
      create_list(:grade_item, 2, :assignment, grade: grade)
      create_list(:grade_item, 2, :quiz, grade: grade)

      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'final', max_marks: 75, obtained_marks: 60 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].join(' ')).to include('must be either 50 or 100')
    end

    it 'rejects obtained_marks greater than max_marks' do
      post '/api/v1/grade_items',
           params: { grade_item: { grade_id: grade.id, category: 'assignment', max_marks: 20, obtained_marks: 25 } },
           headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PUT /api/v1/grade_items/:id' do
    it 'updates the grade item' do
      put "/api/v1/grade_items/#{midterm.id}",
          params: { grade_item: { obtained_marks: 28 } },
          headers: { 'Authorization' => @token }

      expect(response).to have_http_status(:ok)
      midterm.reload
      expect(midterm.obtained_marks).to eq(28)
    end
  end

  describe 'DELETE /api/v1/grade_items/:id' do
    it 'deletes the grade item' do
      expect {
        delete "/api/v1/grade_items/#{midterm.id}",
               headers: { 'Authorization' => @token }
      }.to change(GradeItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
