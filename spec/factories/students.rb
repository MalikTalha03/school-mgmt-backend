FactoryBot.define do
  factory :student do
    association :user, factory: :user, role: :student
    semester { 1 }
    max_credit_per_semester { 21 }
    association :department
  end
end
