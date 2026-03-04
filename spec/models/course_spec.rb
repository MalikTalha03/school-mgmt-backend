require 'rails_helper'

RSpec.describe Course, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:course)).to be_valid
    end
  end

  describe 'validations' do
    it 'validates presence of title' do
      course = build(:course, title: nil)

      expect(course).not_to be_valid
      expect(course.errors[:title]).to include("can't be blank")
    end

    it 'validates presence of credit_hours' do
      course = build(:course, credit_hours: nil)

      expect(course).not_to be_valid
      expect(course.errors[:credit_hours]).to include("can't be blank")
    end

    it 'allows credit_hours from 0 to 4' do
      expect(build(:course, credit_hours: 0)).to be_valid
      expect(build(:course, credit_hours: 4)).to be_valid
    end

    it 'rejects credit_hours outside 0..4' do
      expect(build(:course, credit_hours: -1)).not_to be_valid
      expect(build(:course, credit_hours: 5)).not_to be_valid
    end

    it 'requires department' do
      course = build(:course, department: nil)

      expect(course).not_to be_valid
      expect(course.errors[:department]).to include('must exist')
    end

    it 'requires teacher' do
      course = build(:course, teacher: nil)

      expect(course).not_to be_valid
      expect(course.errors[:teacher]).to include('must exist')
    end
  end

  describe 'teacher_course_limit' do
    it 'prevents assigning a 4th course to the same teacher on create' do
      teacher = create(:teacher)
      create_list(:course, 3, teacher: teacher)
      course = build(:course, teacher: teacher)

      expect(course).not_to be_valid
      expect(course.errors[:teacher]).to include('already has maximum 3 courses assigned')
    end

    it 'does not block update when teacher is unchanged' do
      course = create(:course)

      expect(course.update(title: 'Updated title')).to be true
    end
  end
end
