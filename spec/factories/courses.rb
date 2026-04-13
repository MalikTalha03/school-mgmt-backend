FactoryBot.define do
  factory :course do
    sequence(:title) { |n| "Course #{n}" }
    credit_hours { 3 }
    department { create(:department) }
    teacher { create(:teacher) }
  end
end
