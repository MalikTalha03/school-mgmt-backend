FactoryBot.define do
  factory :course do
    sequence(:title) { |n| "Course #{n}" }
    credit_hours { 3 }
    association :department
    association :teacher
  end
end
