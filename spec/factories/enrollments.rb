FactoryBot.define do
  factory :enrollment do
    association :student
    association :course
    status { :enrolled }
  end
end
