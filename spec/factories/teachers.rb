FactoryBot.define do
  factory :teacher do
    association :user, factory: :user, role: :teacher
    designation { :assistant_professor }
    association :department
  end
end
