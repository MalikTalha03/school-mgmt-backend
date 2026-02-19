class CreateTeachers < ActiveRecord::Migration[8.1]
  def change
    create_table :teachers do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :designation
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
  end
end
