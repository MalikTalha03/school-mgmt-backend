class Teacher < ApplicationRecord
  belongs_to :user
  belongs_to :department

  has_many :courses, dependent: :restrict_with_error

  enum :designation, { visiting_faculty: 0, lecturer: 1, assistant_professor: 2, associate_professor: 3, professor: 4 }

  validates :user_id, uniqueness: true, presence: true
  validates :department_id, presence: true
  validates :designation, presence: true
  validate :max_courses_limit

  private

  def max_courses_limit
    if courses.count > 3
      errors.add(:base, "Teacher cannot teach more than 3 courses")
    end
  end
end
