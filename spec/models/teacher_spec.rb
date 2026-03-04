require 'rails_helper'

RSpec.describe Teacher, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:teacher)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires unique user_id' do
      existing = create(:teacher)
      duplicate = build(:teacher, user: existing.user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('has already been taken')
    end

    it 'requires department' do
      teacher = build(:teacher, department: nil)

      expect(teacher).not_to be_valid
      expect(teacher.errors[:department]).to include('must exist')
    end

    it 'requires designation' do
      teacher = build(:teacher, designation: nil)

      expect(teacher).not_to be_valid
      expect(teacher.errors[:designation]).to include("can't be blank")
    end
  end

  describe 'enums' do
    it 'defines expected designations' do
      expect(described_class.designations.keys).to contain_exactly(
        'visiting_faculty',
        'lecturer',
        'assistant_professor',
        'associate_professor',
        'professor'
      )
    end
  end

  describe 'course limit' do
    it 'adds error when teacher has more than 3 courses' do
      teacher = create(:teacher)
      create_list(:course, 3, teacher: teacher)
      extra_course = create(:course)
      extra_course.update_column(:teacher_id, teacher.id)

      expect(teacher).not_to be_valid
      expect(teacher.errors[:base]).to include('Teacher cannot teach more than 3 courses')
    end
  end

  describe 'dependent restriction' do
    it 'prevents destroy when courses exist' do
      teacher = create(:teacher)
      create(:course, teacher: teacher)

      expect(teacher.destroy).to be false
      expect(teacher.errors.full_messages.join).to include('Cannot delete record because dependent courses exist')
    end
  end
end
