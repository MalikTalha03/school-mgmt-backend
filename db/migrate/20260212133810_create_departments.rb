class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :code
      t.string :name

      t.timestamps
    end
  end
end
