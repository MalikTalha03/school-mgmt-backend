class Api::V1::CoursesController < Api::V1::BaseController
  before_action :set_course, only: [:show, :update, :destroy]
  before_action :validate_credit_hours, only: [:create, :update]
  before_action :validate_teacher_limit, only: [:create, :update]

  def index
    @courses = Course.includes(teacher: [:user, :department], department: []).all
    render json: @courses, include: { teacher: { include: [:user, :department] }, department: {} }
  end

  def show
    render json: @course, include: { teacher: { include: [:user, :department] }, department: {}, students: {} }
  end

  def create
    @course = Course.new(course_params)
    
    if @course.save
      render json: @course, status: :created
    else
      render json: { errors: @course.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @course.update(course_params)
      @course.reload
      render json: @course, include: { teacher: { include: [:user, :department] }, department: {} }
    else
      render json: { errors: @course.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Check for active enrollments
    if @course.enrollments.where(status: [:pending, :approved]).any?
      return render json: { 
        error: "Cannot delete course with active enrollments.",
        active_enrollments: @course.enrollments.where(status: [:pending, :approved]).count
      }, status: :unprocessable_entity
    end
    
    # Check for grade records
    if @course.grades.any?
      return render json: { 
        error: "Cannot delete course with existing grade records. Archive the course instead."
      }, status: :unprocessable_entity
    end
    
    if @course.destroy
      head :no_content
    else
      render json: { errors: @course.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_course
    @course = Course.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Course not found" }, status: :not_found
  end

  def course_params
    params.require(:course).permit(:title, :credit_hours, :department_id, :teacher_id)
  end

  def validate_credit_hours
    credit_hours = params[:course][:credit_hours].to_i if params[:course][:credit_hours].present?
    
    if credit_hours.present? && (credit_hours < 0 || credit_hours > 4)
      render json: { error: "Credit hours must be between 0 and 4" }, status: :unprocessable_entity
    end
  end

  def validate_teacher_limit
    return unless params[:course][:teacher_id].present?
    
    teacher_id = params[:course][:teacher_id]
    teacher = Teacher.find_by(id: teacher_id)
    
    unless teacher
      return render json: { error: "Teacher not found" }, status: :not_found
    end
    
    # When updating, exclude current course from count
    existing_courses = teacher.courses
    existing_courses = existing_courses.where.not(id: params[:id]) if params[:id].present?
    
    if existing_courses.count >= 3
      render json: { 
        error: "Teacher already has maximum 3 courses assigned",
        teacher_id: teacher.id,
        current_courses: existing_courses.count
      }, status: :unprocessable_entity
    end
  end
end
