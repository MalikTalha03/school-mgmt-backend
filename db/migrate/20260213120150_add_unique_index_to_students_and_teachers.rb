class AddUniqueIndexToStudentsAndTeachers < ActiveRecord::Migration[8.1]
  def up
    # Remove existing non-unique indexes
    remove_index :students, :user_id if index_exists?(:students, :user_id)
    remove_index :teachers, :user_id if index_exists?(:teachers, :user_id)

    # Remove duplicate students (keep the oldest one for each user_id)
    execute <<-SQL
      DELETE FROM students
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM students
        GROUP BY user_id
      )
    SQL

    # Remove duplicate teachers (keep the oldest one for each user_id)
    execute <<-SQL
      DELETE FROM teachers
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM teachers
        GROUP BY user_id
      )
    SQL

    # Now add unique indexes
    add_index :students, :user_id, unique: true
    add_index :teachers, :user_id, unique: true
  end

  def down
    remove_index :students, :user_id
    remove_index :teachers, :user_id

    add_index :students, :user_id
    add_index :teachers, :user_id
  end
end
