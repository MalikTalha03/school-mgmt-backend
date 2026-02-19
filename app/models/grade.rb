class Grade < ApplicationRecord
  belongs_to :student
  belongs_to :course

  has_many :grade_items, dependent: :destroy

  validates :student_id, uniqueness: { scope: :course_id, message: "already has a grade for this course" }
  validates :student_id, presence: true
  validates :course_id, presence: true
end
