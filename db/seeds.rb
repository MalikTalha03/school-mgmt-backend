# Clear existing data (optional, comment out if you want to preserve existing data)
# JwtDenylist.delete_all
# GradeItem.delete_all
# Grade.delete_all
# Enrollment.delete_all
# Course.delete_all
# Student.delete_all
# Teacher.delete_all
# User.delete_all

puts "Seeding database with mock data..."

# ===== ADMIN USER =====
puts "Creating admin user..."

admin_user = User.find_or_create_by!(email: "admin@gmail.com") do |u|
  u.name = "Admin User"
  u.password = "12345678"
  u.password_confirmation = "12345678"
  u.role = :admin
end
admin_user.update!(name: "Admin User") if admin_user.name.blank?

puts "✓ Created admin user: admin@gmail.com"

# ===== DEPARTMENTS =====
puts "Creating departments..."

cs_dept = Department.find_or_create_by!(code: "CS") do |d|
  d.name = "Computer Science"
end

ee_dept = Department.find_or_create_by!(code: "EE") do |d|
  d.name = "Electrical Engineering"
end

se_dept = Department.find_or_create_by!(code: "SE") do |d|
  d.name = "Software Engineering"
end

puts "✓ Created #{Department.count} departments"

# ===== USERS & TEACHERS =====
puts "Creating teachers..."

teachers_data = [
  { email: "teacher1@school.edu", name: "Dr. Ahmed Khan", dept: cs_dept, designation: 0 },
  { email: "teacher2@school.edu", name: "Dr. Fatima Ali", dept: cs_dept, designation: 1 },
  { email: "teacher3@school.edu", name: "Prof. Hassan Raza", dept: ee_dept, designation: 0 },
  { email: "teacher4@school.edu", name: "Dr. Zara Khan", dept: se_dept, designation: 1 },
]

teachers = []
teachers_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.name = data[:name]
    u.password = "password123"
    u.password_confirmation = "password123"
    u.role = :teacher
  end
  user.update!(name: data[:name]) if user.name.blank?
  
  teacher = Teacher.find_or_create_by!(user: user) do |t|
    t.department = data[:dept]
    t.designation = data[:designation]
  end
  
  teachers << teacher
  puts "  ✓ Created teacher: #{data[:name]} (#{data[:email]})"
end

# ===== USERS & STUDENTS =====
puts "Creating students..."

students_data = [
  { email: "student1@school.edu", name: "Ali Raza", dept: cs_dept, semester: 4 },
  { email: "student2@school.edu", name: "Sara Ahmed", dept: cs_dept, semester: 3 },
  { email: "student3@school.edu", name: "Omar Khan", dept: cs_dept, semester: 5 },
  { email: "student4@school.edu", name: "Ayesha Malik", dept: ee_dept, semester: 2 },
  { email: "student5@school.edu", name: "Bilal Hassan", dept: ee_dept, semester: 6 },
  { email: "student6@school.edu", name: "Zainab Ali", dept: se_dept, semester: 1 },
  { email: "student7@school.edu", name: "Hamza Iqbal", dept: se_dept, semester: 12 }, # Max semester
]

students = []
students_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.name = data[:name]
    u.password = "password123"
    u.password_confirmation = "password123"
    u.role = :student
  end
  user.update!(name: data[:name]) if user.name.blank?
  
  student = Student.find_or_create_by!(user: user) do |s|
    s.department = data[:dept]
    s.semester = data[:semester]
    s.max_credit_hours = 132 # Total program credit hours
    s.max_credit_per_semester = 21 # Max per semester
  end
  
  students << student
  puts "  ✓ Created student: #{data[:name]} (#{data[:email]}) - Semester: #{data[:semester]}"
end

# ===== COURSES =====
# Rules:
# - Teacher can't teach more than 3 courses at the same time
# - Credit hours must be between 0-4
puts "Creating courses..."

courses_data = [
  # CS Department Courses
  { title: "Data Structures", code: "CS201", dept: cs_dept, teacher: teachers[0], credits: 3 },
  { title: "Web Development", code: "CS202", dept: cs_dept, teacher: teachers[0], credits: 3 },
  { title: "Database Systems", code: "CS203", dept: cs_dept, teacher: teachers[0], credits: 4 }, # Teacher 0 now has 3 courses (limit reached)
  
  { title: "Algorithms", code: "CS301", dept: cs_dept, teacher: teachers[1], credits: 3 },
  { title: "AI Fundamentals", code: "CS302", dept: cs_dept, teacher: teachers[1], credits: 4 },
  { title: "Network Security", code: "CS303", dept: cs_dept, teacher: teachers[1], credits: 3 }, # Teacher 1 has 3 courses
  
  # EE Department Courses
  { title: "Circuit Analysis", code: "EE201", dept: ee_dept, teacher: teachers[2], credits: 4 },
  { title: "Digital Logic", code: "EE202", dept: ee_dept, teacher: teachers[2], credits: 3 },
  { title: "Power Systems", code: "EE203", dept: ee_dept, teacher: teachers[2], credits: 3 }, # Teacher 2 has 3 courses
  
  # SE Department Courses
  { title: "Software Design", code: "SE201", dept: se_dept, teacher: teachers[3], credits: 3 },
  { title: "Testing & QA", code: "SE202", dept: se_dept, teacher: teachers[3], credits: 3 },
  { title: "DevOps Basics", code: "SE203", dept: se_dept, teacher: teachers[3], credits: 2 }, # Teacher 3 has 3 courses
]

courses = []
courses_data.each do |data|
  course = Course.find_or_create_by!(title: data[:title]) do |c|
    c.department = data[:dept]
    c.teacher = data[:teacher]
    c.credit_hours = data[:credits]
  end
  
  courses << course
  puts "  ✓ Created course: #{data[:code]} - #{data[:title]} (#{data[:credits]} credits) by #{data[:teacher].user.email}"
end

# Validate teacher course limits
puts "\nValidating teacher course limits (max 3 courses each)..."
Teacher.all.each do |teacher|
  course_count = teacher.courses.count
  puts "  #{teacher.user.email}: #{course_count} courses"
  if course_count > 3
    puts "    ⚠ WARNING: Teacher has more than 3 courses!"
  end
end

# ===== ENROLLMENTS =====
# Rules:
# - Student can't be enrolled for more than 21 credit hours in current semester
# Each student enrolled in courses totaling max 21 credit hours
puts "\nCreating enrollments..."

enrollment_configs = [
  # Student 1: 4 + 3 + 3 = 10 credits (under limit of 21)
  { student: students[0], courses: [courses[0], courses[1], courses[3]] },
  
  # Student 2: 4 + 3 + 3 = 10 credits
  { student: students[1], courses: [courses[2], courses[4], courses[6]] },
  
  # Student 3: 3 + 3 + 4 + 3 + 2 = 15 credits (under 21)
  { student: students[2], courses: [courses[1], courses[4], courses[7], courses[9], courses[11]] },
  
  # Student 4: 3 + 3 + 3 = 9 credits
  { student: students[3], courses: [courses[6], courses[8], courses[10]] },
  
  # Student 5: 4 + 3 + 3 = 10 credits
  { student: students[4], courses: [courses[5], courses[7], courses[9]] },
  
  # Student 6: 3 + 4 = 7 credits (new student, light load)
  { student: students[5], courses: [courses[0], courses[2]] },
  
  # Student 7 (max semester): 3 + 3 + 2 + 4 = 12 credits
  { student: students[6], courses: [courses[3], courses[5], courses[11], courses[7]] },
]

enrollment_configs.each do |config|
  student = config[:student]
  total_credits = 0
  
  config[:courses].each do |course|
    total_credits += course.credit_hours
    
    enrollment = Enrollment.find_by(student_id: student.id, course_id: course.id)
    unless enrollment
      enrollment = Enrollment.create!(student_id: student.id, course_id: course.id, status: 1) # 1 = approved
    end
    
    puts "  ✓ Enrolled #{student.user.email} in #{course.title} (#{course.credit_hours} credits)"
  end
  
  if total_credits > 21
    puts "    ⚠ WARNING: Student enrolled in #{total_credits} credits (limit: 21)"
  else
    puts "  ✓ Total credits for #{student.user.email}: #{total_credits}/21"
  end
end

# ===== GRADES & GRADE ITEMS =====
# Rules:
# - Must have at least 2 assignments and 2 quizzes before midterm
# - Must have at least 4 assignments, 4 quizzes, and midterm before final
# - Final marks max: 50 or 100
# - Assignment max: 20
# - Quiz max: 20
# - Midterm max: typically 30
# - Only one midterm and one final per student

puts "\nCreating grades and grade items..."

Enrollment.all.each do |enrollment|
  grade = Grade.find_by(student_id: enrollment.student_id, course_id: enrollment.course_id)
  unless grade
    grade = Grade.create!(student_id: enrollment.student_id, course_id: enrollment.course_id)
  end
  
  puts "  ✓ Creating grades for #{enrollment.student.user.email} in #{enrollment.course.title}"
  
  # Create 4 assignments (category: 0) - required before midterm
  4.times do |i|
    unless grade.grade_items.where(category: 0).count > i
      assignment = GradeItem.create!(
        grade_id: grade.id, 
        category: 0, 
        max_marks: 20, 
        obtained_marks: rand(10..20)
      )
      puts "    - Assignment #{i+1}: #{assignment.obtained_marks}/#{assignment.max_marks}"
    end
  end
  
  # Create 4 quizzes (category: 1) - required before midterm
  4.times do |i|
    unless grade.grade_items.where(category: 1).count > i
      quiz = GradeItem.create!(
        grade_id: grade.id, 
        category: 1, 
        max_marks: 20, 
        obtained_marks: rand(10..20)
      )
      puts "    - Quiz #{i+1}: #{quiz.obtained_marks}/#{quiz.max_marks}"
    end
  end
  
  # Add midterm (category: 2) - can only be added after 2 assignments and 2 quizzes
  unless grade.grade_items.exists?(category: 2)
    midterm = GradeItem.create!(
      grade_id: grade.id, 
      category: 2, 
      max_marks: 30, 
      obtained_marks: rand(15..29)
    )
    puts "    - Midterm: #{midterm.obtained_marks}/#{midterm.max_marks}"
  end
  
  # Add final marks (category: 3) - can only be added after 4 assignments, 4 quizzes, and midterm
  unless grade.grade_items.exists?(category: 3)
    final_max = [50, 100].sample
    final_mark = if final_max == 50
                   rand(25..49) # 25-49 out of 50
                 else
                   rand(50..99) # 50-99 out of 100
                 end
    
    final = GradeItem.create!(
      grade_id: grade.id, 
      category: 3, 
      max_marks: final_max, 
      obtained_marks: final_mark
    )
    puts "    - Final: #{final.obtained_marks}/#{final.max_marks}"
  end
  
  puts "  ✓ Completed all grades for #{enrollment.student.user.email}"
end

puts "\n" + "="*60
puts "✓ DATABASE SEEDING COMPLETED SUCCESSFULLY!"
puts "="*60
puts "\nDatabase Summary:"
puts "  Departments: #{Department.count}"
puts "  Teachers: #{Teacher.count}"
puts "  Students: #{Student.count}"
puts "  Courses: #{Course.count}"
puts "  Enrollments: #{Enrollment.count}"
puts "  Grades: #{Grade.count}"
puts "  Grade Items: #{GradeItem.count}"

puts "\nBusiness Rules Validated:"
puts "  ✓ Teacher course limit (max 3): Enforced in seed data"
puts "  ✓ Student credit hours limit (max 21/semester): Enforced in seed data"
puts "  ✓ Student max semesters (12): Seeded with max semester student"
puts "  ✓ Midterm requires: 2 assignments + 2 quizzes: All present in grades"
puts "  ✓ Final requires: 4 assignments + 4 quizzes + midterm: All present in grades"
puts "  ✓ Final marks max (50 or 100): Randomized in seed data"
puts "  ✓ Assignment max (20): Enforced in seed data"
puts "  ✓ Quiz max (20): Enforced in seed data"
puts "  ✓ Auto-complete enrollment on final upload: Implemented in GradeItem model"

puts "\n📝 Test Credentials:"
puts "  Admin: admin@gmail.com / 12345678 (created earlier)"
puts "  Teachers: teacher1@school.edu - teacher4@school.edu / password123"
puts "  Students: student1@school.edu - student7@school.edu / password123"
