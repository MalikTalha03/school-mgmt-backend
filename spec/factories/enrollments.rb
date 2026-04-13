FactoryBot.define do
  factory :enrollment do
    association :student
    association :course
    status { :pending }

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :completed do
      status { :completed }
    end

    trait :withdrawn do
      status { :withdrawn }
    end
  end
end
