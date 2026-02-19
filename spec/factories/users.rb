FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    role { :student }

    trait :admin do
      role { :admin }
    end

    trait :teacher do
      role { :teacher }
    end

    trait :student do
      role { :student }
    end
  end
end
