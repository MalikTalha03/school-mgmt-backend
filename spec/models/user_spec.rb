require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:user)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires name' do
      user = build(:user, name: nil)

      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'requires unique email' do
      create(:user, email: 'duplicate@example.com')
      user = build(:user, email: 'duplicate@example.com')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end
  end

  describe 'enums' do
    it 'defines expected roles' do
      expect(described_class.roles.keys).to contain_exactly('student', 'teacher', 'admin')
    end
  end

  describe 'associations' do
    it 'has one student profile' do
      user = create(:user, :student)
      student = create(:student, user: user)

      expect(user.student).to eq(student)
    end

    it 'has one teacher profile' do
      user = create(:user, :teacher)
      teacher = create(:teacher, user: user)

      expect(user.teacher).to eq(teacher)
    end
  end
end
