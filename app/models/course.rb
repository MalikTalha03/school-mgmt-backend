class Course < ApplicationRecord
  belongs_to :department
  belongs_to :teacher
  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments
  has_many :grades, dependent: :restrict_with_error

  validates :title, presence: true
  validates :credit_hours, presence: true, inclusion: { in: 0..4 }
  validates :department_id, presence: true
  validates :teacher_id, presence: true
  validate :teacher_course_limit

  private

  def teacher_course_limit
    return unless teacher_id_changed? && teacher.present?
    
    if teacher.courses.where.not(id: id).count >= 3
      errors.add(:teacher, "already has maximum 3 courses assigned")
    end
  end
end
