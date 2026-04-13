FactoryBot.define do
  factory :student do
    user { create(:user, :student) }
    semester { 1 }
    max_credit_per_semester { 21 }
    department { create(:department) }
  end
end
