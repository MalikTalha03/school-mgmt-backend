class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist


  enum :role, { student: 0, teacher: 1, admin: 2 }
  has_one :student
  has_one :teacher
  validates :name, presence: true
end
