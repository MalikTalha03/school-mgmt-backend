FactoryBot.define do
  factory :department do
    sequence(:code) { |n| "DEPT#{n}" }
    sequence(:name) { |n| "Department #{n}" }
  end
end
