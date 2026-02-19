class Department < ApplicationRecord
  has_many :teachers, dependent: :restrict_with_error
  has_many :students, dependent: :restrict_with_error
  has_many :courses, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :name, presence: true, uniqueness: true

  # Normalize code to uppercase
  before_validation :normalize_code

  private

  def normalize_code
    self.code = code.upcase if code.present?
  end
end
