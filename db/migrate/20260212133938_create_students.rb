class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :semester
      t.integer :max_credit_hours
      t.integer :max_credit_per_semester
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
  end
end
