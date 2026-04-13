require 'rails_helper'

RSpec.describe GradeItem, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:grade_item)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires max_marks' do
      grade_item = build(:grade_item, max_marks: nil, obtained_marks: nil)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:max_marks]).to include("can't be blank")
    end

    it 'requires max_marks greater than 0' do
      grade_item = build(:grade_item, max_marks: 0)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:max_marks]).to include('must be greater than 0')
    end

    it 'rejects obtained_marks below 0' do
      grade_item = build(:grade_item, obtained_marks: -1)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:obtained_marks]).to include('must be greater than or equal to 0')
    end

    it 'rejects obtained_marks above max_marks' do
      grade_item = build(:grade_item, max_marks: 20, obtained_marks: 21)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:obtained_marks]).to include('must be less than or equal to 20')
    end
  end

  describe 'max marks by category' do
    it 'rejects assignment max_marks above 20' do
      grade_item = build(:grade_item, category: :assignment, max_marks: 21)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:max_marks]).to include('for assignments cannot exceed 20')
    end

    it 'rejects quiz max_marks above 20' do
      grade_item = build(:grade_item, category: :quiz, max_marks: 25)

      expect(grade_item).not_to be_valid
      expect(grade_item.errors[:max_marks]).to include('for quizzes cannot exceed 20')
    end

    it 'rejects final max_marks not equal to 50 or 100' do
      grade = create(:grade)
      create_list(:grade_item, 4, :assignment, grade: grade)
      create_list(:grade_item, 4, :quiz, grade: grade)
      create(:grade_item, :midterm, grade: grade)
      final_item = build(:grade_item, :final, grade: grade, max_marks: 70)

      expect(final_item).not_to be_valid
      expect(final_item.errors[:max_marks]).to include('for finals must be either 50 or 100')
    end

    it 'accepts final max_marks of 50 and 100' do
      grade = create(:grade)
      create_list(:grade_item, 4, :assignment, grade: grade)
      create_list(:grade_item, 4, :quiz, grade: grade)
      create(:grade_item, :midterm, grade: grade)

      expect(build(:grade_item, :final, grade: grade, max_marks: 50, obtained_marks: 45)).to be_valid
      expect(build(:grade_item, :final, grade: grade, max_marks: 100, obtained_marks: 90)).to be_valid
    end
  end

  describe 'midterm prerequisites' do
    it 'rejects midterm without at least 2 assignments and 2 quizzes' do
      grade = create(:grade)
      create(:grade_item, :assignment, grade: grade)
      create(:grade_item, :quiz, grade: grade)
      midterm = build(:grade_item, :midterm, grade: grade)

      expect(midterm).not_to be_valid
      expect(midterm.errors[:base]).to include('Cannot enter midterm marks without at least 2 assignments and 2 quizzes')
    end

    it 'accepts midterm when prerequisites are met' do
      grade = create(:grade)
      create_list(:grade_item, 2, :assignment, grade: grade)
      create_list(:grade_item, 2, :quiz, grade: grade)
      midterm = build(:grade_item, :midterm, grade: grade)

      expect(midterm).to be_valid
    end
  end

  describe 'final prerequisites' do
    it 'rejects final without midterm and enough assignment/quiz entries' do
      grade = create(:grade)
      create_list(:grade_item, 3, :assignment, grade: grade)
      create_list(:grade_item, 3, :quiz, grade: grade)
      final_item = build(:grade_item, :final, grade: grade)

      expect(final_item).not_to be_valid
      expect(final_item.errors[:base]).to include('Cannot enter final marks without midterm and at least 4 assignments and 4 quizzes')
    end

    it 'accepts final when prerequisites are met' do
      grade = create(:grade)
      create_list(:grade_item, 4, :assignment, grade: grade)
      create_list(:grade_item, 4, :quiz, grade: grade)
      create(:grade_item, :midterm, grade: grade)
      final_item = build(:grade_item, :final, grade: grade)

      expect(final_item).to be_valid
    end
  end

  describe 'uniqueness of midterm/final by grade' do
    it 'allows only one midterm per grade' do
      grade = create(:grade)
      create_list(:grade_item, 2, :assignment, grade: grade)
      create_list(:grade_item, 2, :quiz, grade: grade)
      create(:grade_item, :midterm, grade: grade)
      duplicate_midterm = build(:grade_item, :midterm, grade: grade)

      expect(duplicate_midterm).not_to be_valid
      expect(duplicate_midterm.errors[:base]).to include('A midterm entry already exists for this student')
    end

    it 'allows only one final per grade' do
      grade = create(:grade)
      create_list(:grade_item, 4, :assignment, grade: grade)
      create_list(:grade_item, 4, :quiz, grade: grade)
      create(:grade_item, :midterm, grade: grade)
      create(:grade_item, :final, grade: grade)
      duplicate_final = build(:grade_item, :final, grade: grade)

      expect(duplicate_final).not_to be_valid
      expect(duplicate_final.errors[:base]).to include('A final entry already exists for this student')
    end
  end
end
