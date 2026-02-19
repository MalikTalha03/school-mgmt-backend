class GradeItem < ApplicationRecord
  belongs_to :grade

  enum :category, { assignment: 0, quiz: 1, midterm: 2, final: 3 }

  validates :max_marks, presence: true, numericality: { greater_than: 0 }
  validates :obtained_marks, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: :max_marks }, allow_nil: true
  validate :final_marks_prerequisites, if: :final?
  validate :max_marks_by_category

  private

  def final_marks_prerequisites
    return unless grade.present?
    
    has_midterm = grade.grade_items.exists?(category: :midterm)
    has_assignment = grade.grade_items.exists?(category: :assignment)
    has_quiz = grade.grade_items.exists?(category: :quiz)
    
    unless has_midterm && has_assignment && has_quiz
      errors.add(:base, "Cannot enter final marks without midterm, assignment, and quiz marks")
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
end
