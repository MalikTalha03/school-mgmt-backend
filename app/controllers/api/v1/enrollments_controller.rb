class Api::V1::EnrollmentsController < Api::V1::BaseController
  before_action :set_enrollment, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  before_action :validate_enrollment, only: [:create]

  def index
    @enrollments = Enrollment.includes(:student, :course).all
    render json: @enrollments, include: [:student, :course]
  end

  def show
    render json: @enrollment, include: [:student, :course]
  end

  def create
    @enrollment = Enrollment.new(enrollment_params)
    
    if @enrollment.save
      render json: @enrollment, status: :created, include: [:student, :course]
    else
      render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Only allow status updates, not student/course changes
    if enrollment_params.keys.any? { |k| ['student_id', 'course_id'].include?(k) }
      return render json: { error: "Cannot change student or course after enrollment. Drop and re-enroll instead." }, status: :unprocessable_entity
    end
    
    if @enrollment.update(enrollment_params)
      render json: @enrollment
    else
      render json: { errors: @enrollment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Check if there are grades associated
    if @enrollment.student.grades.exists?(course_id: @enrollment.course_id)
      return render json: { 
        error: "Cannot delete enrollment with existing grades. Change status to 'dropped' instead." 
      }, status: :unprocessable_entity
    end
    
    if @enrollment.destroy
      head :no_content
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

  def enrollment_params
    params.require(:enrollment).permit(:student_id, :course_id, :status)
  end

  def validate_enrollment
    student = Student.find_by(id: params[:enrollment][:student_id])
    course = Course.find_by(id: params[:enrollment][:course_id])
    
    unless student
      return render json: { error: "Student not found" }, status: :not_found
    end
    
    unless course
      return render json: { error: "Course not found" }, status: :not_found
    end
    
    # Check semester limit
    if student.semester.present? && student.semester > 12
      return render json: { error: "Student has exceeded maximum semester limit (12)" }, status: :unprocessable_entity
    end
    
    # Check credit hours limit
    unless student.can_enroll_in_course?(course)
      max_credits = student.max_credit_per_semester || 21
      current_credits = student.current_semester_credits
      
      return render json: { 
        error: "Enrollment would exceed maximum credit hours for this semester",
        max_credits: max_credits,
        current_credits: current_credits,
        course_credits: course.credit_hours,
        total_would_be: current_credits + course.credit_hours
      }, status: :unprocessable_entity
    end
    
    # Check for duplicate enrollment
    if Enrollment.exists?(student_id: student.id, course_id: course.id, status: [:enrolled, :completed])
      return render json: { 
        error: "Student is already enrolled in this course or has completed it" 
      }, status: :unprocessable_entity
    end
  end
end
