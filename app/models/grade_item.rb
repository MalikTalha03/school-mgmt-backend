class GradeItem < ApplicationRecord
  belongs_to :grade

  enum :category, { assignment: 0, quiz: 1, midterm: 2, final: 3 }

  validates :max_marks, presence: true, numericality: { greater_than: 0 }
  validates :obtained_marks, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: :max_marks }, allow_nil: true
  validate :midterm_prerequisites, if: :midterm?
  validate :final_marks_prerequisites, if: :final?
  validate :max_marks_by_category
  validate :unique_midterm_and_final

  after_create :complete_enrollment_if_final

  private

  def midterm_prerequisites
    return unless grade.present?
    
    assignment_count = grade.grade_items.where(category: :assignment).count
    quiz_count = grade.grade_items.where(category: :quiz).count
    
    unless assignment_count >= 2 && quiz_count >= 2
      errors.add(:base, "Cannot enter midterm marks without at least 2 assignments and 2 quizzes")
    end
  end

  def final_marks_prerequisites
    return unless grade.present?
    
    has_midterm = grade.grade_items.exists?(category: :midterm)
    assignment_count = grade.grade_items.where(category: :assignment).count
    quiz_count = grade.grade_items.where(category: :quiz).count
    
    unless has_midterm && assignment_count >= 4 && quiz_count >= 4
      errors.add(:base, "Cannot enter final marks without midterm and at least 4 assignments and 4 quizzes")
    end
  end

  def complete_enrollment_if_final
    return unless final? && grade.present?
    
    enrollment = Enrollment.find_by(student_id: grade.student_id, course_id: grade.course_id)
    if enrollment && enrollment.approved?
      enrollment.update(status: :completed)
    end
  end

  def max_marks_by_category
    case category
    when 'assignment'
      if max_marks.present? && max_marks > 20
        errors.add(:max_marks, "for assignments cannot exceed 20")
      end
    when 'quiz'
      if max_marks.present? && max_marks > 20
        errors.add(:max_marks, "for quizzes cannot exceed 20")
      end
    when 'final'
      if max_marks.present? && ![50, 100].include?(max_marks)
        errors.add(:max_marks, "for finals must be either 50 or 100")
      end
    end
  end

  def unique_midterm_and_final
    return unless grade.present?
    return unless midterm? || final?
    
    existing = grade.grade_items.where(category: category)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:base, "A #{category} entry already exists for this student")
    end
  end
end
