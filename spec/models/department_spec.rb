require 'rails_helper'

RSpec.describe Department, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:department)).to be_valid
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      department = build(:department, name: nil)

      expect(department).not_to be_valid
      expect(department.errors[:name]).to include("can't be blank")
    end

    it 'validates uniqueness of name' do
      create(:department, name: 'Computer Science')
      department = build(:department, name: 'Computer Science')

      expect(department).not_to be_valid
      expect(department.errors[:name]).to include('has already been taken')
    end

    it 'validates presence of code' do
      department = build(:department, code: nil)

      expect(department).not_to be_valid
      expect(department.errors[:code]).to include("can't be blank")
    end

    it 'validates uniqueness of code' do
      create(:department, code: 'CSE')
      department = build(:department, code: 'cse')

      expect(department).not_to be_valid
      expect(department.errors[:code]).to include('has already been taken')
    end

    it 'validates max length of code' do
      department = build(:department, code: 'ABCDEFGHIJK')

      expect(department).not_to be_valid
      expect(department.errors[:code]).to include('is too long (maximum is 10 characters)')
    end
  end

  describe 'callbacks' do
    it 'normalizes code to uppercase before validation' do
      department = build(:department, code: 'cse')

      department.validate

      expect(department.code).to eq('CSE')
    end
  end

  describe 'dependent restrictions' do
    it 'prevents deletion when teachers exist' do
      department = create(:department)
      create(:teacher, department: department)

      expect(department.destroy).to be false
      expect(department.errors.full_messages.join).to include('Cannot delete record because dependent teachers exist')
    end
  end
end
