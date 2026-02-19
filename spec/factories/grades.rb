FactoryBot.define do
  factory :grade do
    association :student
    association :course
  end
end
