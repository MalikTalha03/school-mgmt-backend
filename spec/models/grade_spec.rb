require 'rails_helper'

RSpec.describe Grade, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:grade)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires student' do
      grade = build(:grade, student: nil)

      expect(grade).not_to be_valid
      expect(grade.errors[:student]).to include('must exist')
    end

    it 'requires course' do
      grade = build(:grade, course: nil)

      expect(grade).not_to be_valid
      expect(grade.errors[:course]).to include('must exist')
    end

    it 'enforces uniqueness of student scoped to course' do
      existing = create(:grade)
      duplicate = build(:grade, student: existing.student, course: existing.course)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:student_id]).to include('already has a grade for this course')
    end
  end

  describe 'associations' do
    it 'destroys grade_items when grade is destroyed' do
      grade = create(:grade)
      create(:grade_item, grade: grade)

      expect { grade.destroy }.to change(GradeItem, :count).by(-1)
    end
  end
end
