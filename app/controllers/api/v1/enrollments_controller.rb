class Api::V1::EnrollmentsController < Api::V1::BaseController
  before_action :set_enrollment, only: [ :show, :update, :approve, :reject, :complete, :drop, :withdraw ]
  before_action :require_admin!, only: [ :approve, :reject, :complete, :drop, :create, :announce_results ]
  before_action :validate_enrollment_request, only: [ :request_enrollment ]

  def index
    @enrollments = Enrollment.includes(student: [ :user, :department ], course: [ :teacher, :department ])
    render json: @enrollments, include: {
      student: { include: [ :user, :department ] },
      course: { include: [ :teacher, :department ] }
    }
  end

  def show
    render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
  end

  # Student initiates enrollment request
  def request_enrollment
    student = current_user.student

    unless student
      return render json: { error: "Only students can request enrollments" }, status: :forbidden
    end

    @enrollment = Enrollment.request_enrollment(
      student_id: student.id,
      course_id: params[:course_id]
    )

    if @enrollment.persisted?
      @enrollment.reload
      render json: @enrollment, status: :created, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
    else
      render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Admin creates enrollment directly (approved status)
  def create
    @enrollment = Enrollment.new(enrollment_params)
    @enrollment.status = :approved # Admin-created enrollments are auto-approved
    @enrollment.semester ||= Student.find_by(id: @enrollment.student_id)&.semester

    if @enrollment.save
      @enrollment.reload
      render json: @enrollment, status: :created, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
    else
      render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Admin approves pending enrollment
  def approve
    if @enrollment.pending?
      if @enrollment.approve!
        @enrollment.reload
        render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
      else
        render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Only pending enrollments can be approved" }, status: :unprocessable_entity
    end
  end

  # Admin rejects pending enrollment
  def reject
    if @enrollment.pending?
      if @enrollment.reject!
        @enrollment.reload
        render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
      else
        render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Only pending enrollments can be rejected" }, status: :unprocessable_entity
    end
  end

  # Admin marks enrollment as completed
  def complete
    if @enrollment.approved?
      if @enrollment.mark_completed!
        @enrollment.reload
        render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
      else
        render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Only approved enrollments can be marked as completed" }, status: :unprocessable_entity
    end
  end

  # Admin drops student from course
  def drop
    if @enrollment.approved?
      if @enrollment.drop!
        @enrollment.reload
        render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
      else
        render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Only approved enrollments can be dropped" }, status: :unprocessable_entity
    end
  end

  # Student withdraws from approved enrollment
  def withdraw
    student = current_user.student

    unless student && @enrollment.student_id == student.id
      return render json: { error: "You can only withdraw from your own enrollments" }, status: :forbidden
    end

    if @enrollment.withdraw!
      @enrollment.reload
      render json: @enrollment, include: { student: { include: [ :user, :department ] }, course: { include: [ :teacher, :department ] } }
    else
      render json: { error: "Only approved enrollments can be withdrawn" }, status: :unprocessable_entity
    end
  end

  # Admin announces results: checks all approved enrollments are fully graded,
  # then promotes student semesters and marks enrollments as completed.
  def announce_results
    approved_enrollments = Enrollment.includes(:course, student: :user).where(status: :approved)

    if approved_enrollments.empty?
      return render json: {
        success: false,
        message: "No active enrollments found to announce results for"
      }, status: :unprocessable_entity
    end

    # Preload all relevant grades with their items in 2 queries (avoids N+1 per enrollment)
    student_ids = approved_enrollments.map(&:student_id).uniq
    course_ids  = approved_enrollments.map(&:course_id).uniq
    grades = Grade.includes(:grade_items).where(student_id: student_ids, course_id: course_ids)
    grade_lookup = grades.index_by { |g| [ g.student_id, g.course_id ] }

    # Detect courses that have students without a final grade_item
    incomplete_courses = {}

    approved_enrollments.each do |enrollment|
      grade = grade_lookup[[ enrollment.student_id, enrollment.course_id ]]
      has_final = grade && grade.grade_items.any? { |gi| gi.category.to_s == "final" }

      unless has_final
        course = enrollment.course
        incomplete_courses[course.id] ||= { id: course.id, title: course.title, incomplete_count: 0 }
        incomplete_courses[course.id][:incomplete_count] += 1
      end
    end

    if incomplete_courses.any?
      return render json: {
        success: false,
        message: "Some grades are incomplete",
        incomplete_courses: incomplete_courses.values
      }
    end

    # All graded — promote semesters and complete enrollments
    student_ids = approved_enrollments.map(&:student_id).uniq
    promoted_count = 0

    Student.where(id: student_ids).each do |student|
      if student.semester < 12
        student.update_column(:semester, student.semester + 1)
        promoted_count += 1
      end
    end

    completed_count = approved_enrollments.count
    Enrollment.where(status: :approved).update_all(status: 3) # 3 = completed

    render json: {
      success: true,
      message: "Results announced successfully!",
      promoted_count: promoted_count,
      completed_count: completed_count
    }
  end

  def update
    # Only allow status updates to completed/dropped, not student/course changes
    if enrollment_params.keys.any? { |k| [ "student_id", "course_id" ].include?(k) }
      return render json: { error: "Cannot change student or course after enrollment. Drop and re-enroll instead." }, status: :unprocessable_entity
    end

    if @enrollment.update(enrollment_params)
      render json: @enrollment
    else
      render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_enrollment
    @enrollment = Enrollment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Enrollment not found" }, status: :not_found
  end

  def require_admin!
    unless current_user.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end

  def enrollment_params
    params.require(:enrollment).permit(:student_id, :course_id, :status, :semester)
  end

  def validate_enrollment_request
    course = Course.find_by(id: params[:course_id])
    student = current_user.student

    unless course
      return render json: { error: "Course not found" }, status: :not_found
    end

    unless student
      return render json: { error: "Student record not found" }, status: :not_found
    end

    # Check semester limit
    if student.semester.present? && student.semester > 12
      return render json: { error: "You have exceeded maximum semester limit (12)" }, status: :unprocessable_entity
    end

    # Check for duplicate enrollment
    if Enrollment.exists?(student_id: student.id, course_id: course.id, status: [ :pending, :approved, :completed ])
      return render json: {
        error: "You already have a pending/approved enrollment or have completed this course"
      }, status: :unprocessable_entity
    end

    # Enforce credit hours limit: count approved + pending enrollments
    max_credits = student.max_credit_per_semester || 21
    current_credits = student.current_semester_credits

    if (current_credits + course.credit_hours) > max_credits
      remaining = max_credits - current_credits
      render json: {
        error: "Credit hour limit exceeded. You have #{current_credits}/#{max_credits} credit hours (approved + pending). " \
               "This course requires #{course.credit_hours} credit hours but you only have #{[ remaining, 0 ].max} remaining."
      }, status: :unprocessable_entity
    end
  end
end
