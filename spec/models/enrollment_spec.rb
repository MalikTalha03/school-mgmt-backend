require 'rails_helper'

RSpec.describe Enrollment, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:enrollment)).to be_valid
    end
  end

  describe 'enums' do
    it 'defines expected statuses' do
      expect(described_class.statuses.keys).to contain_exactly(
        'pending',
        'approved',
        'rejected',
        'completed',
        'dropped',
        'withdrawn'
      )
    end
  end

  describe 'validations' do
    it 'enforces uniqueness of student within same course' do
      enrollment = create(:enrollment)
      duplicate = build(:enrollment, student: enrollment.student, course: enrollment.course)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:student_id]).to include('is already enrolled in this course')
    end

    it 'rejects enrollment when student semester exceeds 12' do
      student = build(:student, semester: 13)
      enrollment = build(:enrollment, student: student)

      expect(enrollment).not_to be_valid
      expect(enrollment.errors[:base]).to include('Student has exceeded maximum semester limit (12)')
    end

    it 'rejects approved enrollment that exceeds credit limit' do
      student = create(:student, max_credit_per_semester: 6)
      create(:enrollment, :approved, student: student, course: create(:course, credit_hours: 3))
      create(:enrollment, student: student, status: :pending, course: create(:course, credit_hours: 3))

      enrollment = build(:enrollment, :approved, student: student, course: create(:course, credit_hours: 1))

      expect(enrollment).not_to be_valid
      expect(enrollment.errors[:base]).to include('Enrollment would exceed maximum credit hours (6) for this semester')
    end

    it 'allows approved enrollment when within limit' do
      student = create(:student, max_credit_per_semester: 6)
      create(:enrollment, :approved, student: student, course: create(:course, credit_hours: 3))
      enrollment = build(:enrollment, :approved, student: student, course: create(:course, credit_hours: 3))

      expect(enrollment).to be_valid
    end
  end

  describe '.request_enrollment' do
    it 'creates pending enrollment with student current semester' do
      student = create(:student, semester: 4)
      course = create(:course)

      enrollment = described_class.request_enrollment(student_id: student.id, course_id: course.id)

      expect(enrollment).to be_persisted
      expect(enrollment.status).to eq('pending')
      expect(enrollment.semester).to eq(4)
      expect(enrollment.student_id).to eq(student.id)
      expect(enrollment.course_id).to eq(course.id)
    end
  end

  describe 'status transitions' do
    it 'approves enrollment' do
      enrollment = create(:enrollment, status: :pending)

      expect(enrollment.approve!).to be true
      expect(enrollment.reload.status).to eq('approved')
    end

    it 'rejects enrollment' do
      enrollment = create(:enrollment, status: :pending)

      expect(enrollment.reject!).to be true
      expect(enrollment.reload.status).to eq('rejected')
    end

    it 'marks enrollment completed' do
      enrollment = create(:enrollment, :approved)

      expect(enrollment.mark_completed!).to be true
      expect(enrollment.reload.status).to eq('completed')
    end

    it 'drops enrollment' do
      enrollment = create(:enrollment, :approved)

      expect(enrollment.drop!).to be true
      expect(enrollment.reload.status).to eq('dropped')
    end

    it 'allows withdrawal only when approved' do
      approved_enrollment = create(:enrollment, :approved)
      pending_enrollment = create(:enrollment, status: :pending)

      expect(approved_enrollment.withdraw!).to be true
      expect(approved_enrollment.reload.status).to eq('withdrawn')

      expect(pending_enrollment.withdraw!).to be false
      expect(pending_enrollment.reload.status).to eq('pending')
    end
  end
end
