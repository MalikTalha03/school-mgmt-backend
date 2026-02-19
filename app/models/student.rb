class Student < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :grades, dependent: :destroy

  validates :user_id, uniqueness: true, presence: true
  validates :department_id, presence: true
  validates :semester, numericality: { less_than_or_equal_to: 12, greater_than: 0 }, allow_nil: true
  validates :max_credit_per_semester, numericality: { less_than_or_equal_to: 21, greater_than: 0 }, allow_nil: true

  def current_semester_credits
    enrollments.joins(:course).where(status: :enrolled).sum('courses.credit_hours')
  end

  def can_enroll_in_course?(course)
    return false if semester.present? && semester > 12
    
    max_credits = max_credit_per_semester || 21
    current_credits = current_semester_credits
    
    (current_credits + course.credit_hours) <= max_credits
  end
end
