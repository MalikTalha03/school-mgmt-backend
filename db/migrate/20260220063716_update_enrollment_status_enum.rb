class UpdateEnrollmentStatusEnum < ActiveRecord::Migration[8.1]
  def up
    # Update existing values to new enum mapping
    # Old: enrolled=0, completed=1, dropped=2
    # New: pending=0, approved=1, rejected=2, completed=3, dropped=4

    # First, move to temporary high values to avoid conflicts
    execute "UPDATE enrollments SET status = 103 WHERE status = 1" # completed temp
    execute "UPDATE enrollments SET status = 104 WHERE status = 2" # dropped temp
    execute "UPDATE enrollments SET status = 1 WHERE status = 0"   # enrolled -> approved

    # Now set final values
    execute "UPDATE enrollments SET status = 3 WHERE status = 103" # completed final
    execute "UPDATE enrollments SET status = 4 WHERE status = 104" # dropped final
  end

  def down
    # Reverse migration
    # New -> Old: approved=1->enrolled=0, completed=3->completed=1, dropped=4->dropped=2, pending=0->enrolled=0, rejected=2->dropped=2
    execute "UPDATE enrollments SET status = 101 WHERE status = 1" # approved temp
    execute "UPDATE enrollments SET status = 0 WHERE status = 101" # approved -> enrolled
    execute "UPDATE enrollments SET status = 1 WHERE status = 3"   # completed -> completed
    execute "UPDATE enrollments SET status = 2 WHERE status = 4"   # dropped -> dropped
    execute "UPDATE enrollments SET status = 0 WHERE status = 0"   # pending -> enrolled
    execute "UPDATE enrollments SET status = 2 WHERE status = 2"   # rejected -> dropped
  end
end
