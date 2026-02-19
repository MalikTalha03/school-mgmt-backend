FactoryBot.define do
  factory :grade_item do
    association :grade
    category { :midterm }
    max_marks { 30 }
    obtained_marks { 25 }

    trait :assignment do
      category { :assignment }
      max_marks { 20 }
      obtained_marks { 18 }
    end

    trait :quiz do
      category { :quiz }
      max_marks { 20 }
      obtained_marks { 15 }
    end

    trait :midterm do
      category { :midterm }
      max_marks { 30 }
      obtained_marks { 25 }
    end

    trait :final do
      category { :final }
      max_marks { 50 }
      obtained_marks { 45 }
    end
  end
end
