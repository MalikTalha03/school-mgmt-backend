class Enrollment < ApplicationRecord
  belongs_to :student
  belongs_to :course

  enum :status, { enrolled: 0, completed: 1, dropped: 2 }

  validates :student_id, uniqueness: { scope: :course_id, message: "is already enrolled in this course" }
  validate :student_credit_limit, if: :enrolled?
  validate :student_semester_limit

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
