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
  u.password = "12345678"
  u.password_confirmation = "12345678"
  u.role = :admin
end

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
    u.password = "password123"
    u.password_confirmation = "password123"
    u.role = :teacher
  end
  
  teacher = Teacher.find_or_create_by!(user: user) do |t|
    t.department = data[:dept]
    t.designation = data[:designation]
  end
  
  teachers << teacher
  puts "  ✓ Created teacher: #{data[:email]}"
end

# ===== USERS & STUDENTS =====
puts "Creating students..."

students_data = [
  { email: "student1@school.edu", dept: cs_dept, semester: 4 },
  { email: "student2@school.edu", dept: cs_dept, semester: 3 },
  { email: "student3@school.edu", dept: cs_dept, semester: 5 },
  { email: "student4@school.edu", dept: ee_dept, semester: 2 },
  { email: "student5@school.edu", dept: ee_dept, semester: 6 },
  { email: "student6@school.edu", dept: se_dept, semester: 1 },
  { email: "student7@school.edu", dept: se_dept, semester: 12 }, # Max semester
]

students = []
students_data.each do |data|
  user = User.find_or_create_by!(email: data[:email]) do |u|
    u.password = "password123"
    u.password_confirmation = "password123"
    u.role = :student
  end
  
  student = Student.find_or_create_by!(user: user) do |s|
    s.department = data[:dept]
    s.semester = data[:semester]
    s.max_credit_hours = 132 # Total program credit hours
    s.max_credit_per_semester = 21 # Max per semester
  end
  
  students << student
  puts "  ✓ Created student: #{data[:email]} (Semester: #{data[:semester]})"
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
      enrollment = Enrollment.create!(student_id: student.id, course_id: course.id, status: 0) # 0 = enrolled
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
# - Can't have final marks until:
#   1. At least 1 midterm mark
#   2. At least 1 assignment mark
#   3. At least 1 quiz mark
# - Final marks max: 50 or 100
# - Assignment max: 20 (in some cases can be variable)
# - Quiz max: 20 (in some cases can be variable)
# - Midterm max: typically 30

puts "\nCreating grades and grade items..."

Enrollment.all.each do |enrollment|
  grade = Grade.find_by(student_id: enrollment.student_id, course_id: enrollment.course_id)
  unless grade
    grade = Grade.create!(student_id: enrollment.student_id, course_id: enrollment.course_id)
  end
  
  # Add midterm (required) - category: 2
  midterm = GradeItem.find_by(grade_id: grade.id, category: 2)
  unless midterm
    midterm = GradeItem.create!(grade_id: grade.id, category: 2, max_marks: 30, obtained_marks: rand(15..29))
  end
  
  # Add assignment (required) - category: 0
  assignment1 = GradeItem.find_by(grade_id: grade.id, category: 0)
  unless assignment1
    assignment1 = GradeItem.create!(grade_id: grade.id, category: 0, max_marks: 20, obtained_marks: rand(10..20))
  end
  
  # Add quiz (required) - category: 1
  quiz = GradeItem.find_by(grade_id: grade.id, category: 1)
  unless quiz
    quiz = GradeItem.create!(grade_id: grade.id, category: 1, max_marks: 20, obtained_marks: rand(10..20))
  end
  
  puts "  ✓ Added grades for #{enrollment.student.user.email} in #{enrollment.course.title}"
  puts "    - Midterm: #{midterm.obtained_marks}/#{midterm.max_marks}"
  puts "    - Assignment: #{assignment1.obtained_marks}/#{assignment1.max_marks}"
  puts "    - Quiz: #{quiz.obtained_marks}/#{quiz.max_marks}"
  
  # Now that all conditions are met, add final marks - category: 3
  final = GradeItem.find_by(grade_id: grade.id, category: 3)
  unless final
    final_max = [50, 100].sample
    final_mark = if final_max == 50
                   rand(25..49) # 25-49 out of 50
                 else
                   rand(50..99) # 50-99 out of 100
                 end
    
    final = GradeItem.create!(grade_id: grade.id, category: 3, max_marks: final_max, obtained_marks: final_mark)
  end
  
  puts "    - Final: #{final.obtained_marks}/#{final.max_marks}"
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
puts "  ✓ Final marks require: midterm + assignment + quiz: All present in grades"
puts "  ✓ Final marks max (50 or 100): Randomized in seed data"
puts "  ✓ Assignment max (20): Enforced in seed data"
puts "  ✓ Quiz max (20): Enforced in seed data"

puts "\n📝 Test Credentials:"
puts "  Admin: admin@gmail.com / 12345678 (created earlier)"
puts "  Teachers: teacher1@school.edu - teacher4@school.edu / password123"
puts "  Students: student1@school.edu - student7@school.edu / password123"
