FactoryBot.define do
  factory :jwt_denylist do
    jti { "MyString" }
    exp { "2026-02-13 14:36:36" }
  end
end
