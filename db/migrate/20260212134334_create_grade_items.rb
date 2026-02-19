class CreateGradeItems < ActiveRecord::Migration[8.1]
  def change
    create_table :grade_items do |t|
      t.references :grade, null: false, foreign_key: true
      t.integer :category
      t.integer :max_marks
      t.integer :obtained_marks

      t.timestamps
    end
  end
end
