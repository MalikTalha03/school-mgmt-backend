require 'rails_helper'

RSpec.describe Student, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:student)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires unique user_id' do
      existing = create(:student)
      duplicate = build(:student, user: existing.user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('has already been taken')
    end

    it 'requires department' do
      student = build(:student, department: nil)

      expect(student).not_to be_valid
      expect(student.errors[:department]).to include('must exist')
    end

    it 'rejects semester less than 1' do
      student = build(:student, semester: 0)

      expect(student).not_to be_valid
      expect(student.errors[:semester]).to include('must be greater than 0')
    end

    it 'rejects semester greater than 12' do
      student = build(:student, semester: 13)

      expect(student).not_to be_valid
      expect(student.errors[:semester]).to include('must be less than or equal to 12')
    end

    it 'allows nil semester' do
      student = build(:student, semester: nil)

      expect(student).to be_valid
    end

    it 'rejects max_credit_per_semester less than 1' do
      student = build(:student, max_credit_per_semester: 0)

      expect(student).not_to be_valid
      expect(student.errors[:max_credit_per_semester]).to include('must be greater than 0')
    end

    it 'rejects max_credit_per_semester greater than 21' do
      student = build(:student, max_credit_per_semester: 22)

      expect(student).not_to be_valid
      expect(student.errors[:max_credit_per_semester]).to include('must be less than or equal to 21')
    end
  end

  describe '#current_semester_credits' do
    it 'sums approved and pending enrollment credits only' do
      student = create(:student)
      approved_course = create(:course, credit_hours: 3)
      pending_course = create(:course, credit_hours: 2)
      rejected_course = create(:course, credit_hours: 4)

      create(:enrollment, :approved, student: student, course: approved_course)
      create(:enrollment, student: student, course: pending_course, status: :pending)
      create(:enrollment, :rejected, student: student, course: rejected_course)

      expect(student.current_semester_credits).to eq(5)
    end
  end

  describe '#can_enroll_in_course?' do
    it 'returns false if student semester exceeds 12' do
      student = build(:student, semester: 13)
      course = create(:course, credit_hours: 1)

      expect(student.can_enroll_in_course?(course)).to be false
    end

    it 'uses student custom max credits when present' do
      student = create(:student, max_credit_per_semester: 6)
      existing_course = create(:course, credit_hours: 3)
      new_course = create(:course, credit_hours: 4)

      create(:enrollment, :approved, student: student, course: existing_course)

      expect(student.can_enroll_in_course?(new_course)).to be false
    end

    it 'uses default max credits when custom max is nil' do
      student = create(:student, max_credit_per_semester: nil)
      existing_course = create(:course, credit_hours: 3)
      new_course = create(:course, credit_hours: 4)

      create(:enrollment, :approved, student: student, course: existing_course)

      expect(student.can_enroll_in_course?(new_course)).to be true
    end
  end

  describe '#can_promote_to_next_semester?' do
    it 'returns false when semester is nil' do
      student = create(:student, semester: nil)

      expect(student.can_promote_to_next_semester?).to be false
    end

    it 'returns false when semester is 12 or above' do
      student = create(:student, semester: 12)

      expect(student.can_promote_to_next_semester?).to be false
    end

    it 'returns false when approved enrollments exist' do
      student = create(:student, semester: 2)
      create(:enrollment, :approved, student: student)

      expect(student.can_promote_to_next_semester?).to be false
    end

    it 'returns false when pending enrollments exist' do
      student = create(:student, semester: 2)
      create(:enrollment, student: student, status: :pending)

      expect(student.can_promote_to_next_semester?).to be false
    end

    it 'returns true when all constraints are met' do
      student = create(:student, semester: 2)
      create(:enrollment, :completed, student: student)

      expect(student.can_promote_to_next_semester?).to be true
    end
  end

  describe '#promote_to_next_semester!' do
    it 'increments semester when promotable' do
      student = create(:student, semester: 2)
      create(:enrollment, :completed, student: student)

      expect(student.promote_to_next_semester!).to be true
      expect(student.reload.semester).to eq(3)
    end

    it 'returns false when not promotable' do
      student = create(:student, semester: 12)

      expect(student.promote_to_next_semester!).to be false
      expect(student.reload.semester).to eq(12)
    end
  end
end
