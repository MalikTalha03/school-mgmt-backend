class AddSemesterToEnrollments < ActiveRecord::Migration[8.1]
  def change
    add_column :enrollments, :semester, :integer
  end
end
