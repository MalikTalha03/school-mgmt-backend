FactoryBot.define do
  factory :grade do
    student { create(:student) }
    course { create(:course) }
  end
end
