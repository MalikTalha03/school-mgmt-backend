class Enrollment < ApplicationRecord
  belongs_to :student
  belongs_to :course

  enum :status, { pending: 0, approved: 1, rejected: 2, completed: 3, dropped: 4, withdrawn: 5 }

  validates :student_id, uniqueness: { scope: :course_id, message: "is already enrolled in this course" }
  validate :student_credit_limit, if: :approved?
  validate :student_semester_limit

  # Students can only create pending enrollments
  def self.request_enrollment(student_id:, course_id:)
    create(
      student_id: student_id,
      course_id: course_id,
      status: :pending
    )
  end

  # Admin actions
  def approve!
    update(status: :approved)
  end

  def reject!
    update(status: :rejected)
  end

  def mark_completed!
    update(status: :completed)
  end

  def drop!
    update(status: :dropped)
  end

  # Student action
  def withdraw!
    return false unless approved?
    update(status: :withdrawn)
  end

  private

  def student_credit_limit
    return unless student.present? && course.present? && status_changed? || new_record?

    max_credits = student.max_credit_per_semester || 21
    current_credits = student.current_semester_credits

    # Subtract current course credits if updating existing enrollment
    current_credits -= course.credit_hours unless new_record?

    if (current_credits + course.credit_hours) > max_credits
      errors.add(:base, "Enrollment would exceed maximum credit hours (#{max_credits}) for this semester")
    end
  end

  def student_semester_limit
    if student.present? && student.semester.present? && student.semester > 12
      errors.add(:base, "Student has exceeded maximum semester limit (12)")
    end
  end
end
