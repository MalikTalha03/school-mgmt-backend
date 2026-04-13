FactoryBot.define do
  factory :teacher do
    user { create(:user, :teacher) }
    designation { :assistant_professor }
    department { create(:department) }
  end
end
