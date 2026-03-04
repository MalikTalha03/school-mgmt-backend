class Api::V1::GradesController < Api::V1::BaseController
  before_action :set_grade, only: [ :show, :update, :destroy ]
  before_action :validate_grade_prerequisites, only: [ :create ]
  before_action -> { require_roles(:admin, :teacher) }, only: [ :create, :update, :destroy ]
  before_action :authorize_grade_read!, only: [ :show ]
  before_action :authorize_grade_write!, only: [ :create, :update, :destroy ]

  def index
    @grades = Grade.includes(:student, :course, :grade_items)
    @grades = if admin?
      @grades
    elsif student?
      student_record = current_user.student
      student_record ? @grades.where(student_id: student_record.id) : Grade.none
    elsif teacher?
      teacher_record = current_user.teacher
      teacher_record ? @grades.joins(:course).where(courses: { teacher_id: teacher_record.id }) : Grade.none
    else
      Grade.none
    end

    render json: @grades.map { |grade|
      grade.as_json(include: {
        student: { only: [ :id ], include: { user: { only: [ :email ] } } },
        course: { only: [ :id, :title, :credit_hours ] },
        grade_items: { only: [ :id, :category, :max_marks, :obtained_marks ] }
      })
    }
  end

  def show
    render json: @grade, include: {
      student: { include: :user },
      course: {},
      grade_items: {}
    }
  end

  def create
    @grade = Grade.new(grade_params)

    if @grade.save
      render json: @grade, status: :created, include: [ :student, :course, :grade_items ]
    else
      render json: { errors: @grade.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @grade.update(grade_params)
      render json: @grade, include: [ :student, :course, :grade_items ]
    else
      render json: { errors: @grade.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @grade.destroy
      head :no_content
    else
      render json: { errors: @grade.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_grade
    @grade = Grade.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Grade not found" }, status: :not_found
  end

  def grade_params
    params.require(:grade).permit(:student_id, :course_id)
  end

  def validate_grade_prerequisites
    student_id = params[:grade][:student_id]
    course_id = params[:grade][:course_id]

    # Check if enrollment exists
    enrollment = Enrollment.find_by(student_id: student_id, course_id: course_id)

    unless enrollment
      return render json: {
        error: "Cannot create grade without active enrollment",
        suggestion: "Student must be enrolled in the course first"
      }, status: :unprocessable_entity
    end

    # Check if grade already exists
    if Grade.exists?(student_id: student_id, course_id: course_id)
      render json: {
        error: "Grade record already exists for this student and course",
        suggestion: "Use update endpoint or add grade items to existing grade"
      }, status: :unprocessable_entity
    end
  end

  def authorize_grade_read!
    return if admin?
    return if student? && current_user.student&.id == @grade.student_id
    return if teacher? && current_user.teacher&.id == @grade.course.teacher_id

    render json: { error: "Forbidden: insufficient permissions" }, status: :forbidden
  end

  def authorize_grade_write!
    return if admin?
    return if teacher_can_manage_grade?

    render json: { error: "Forbidden: insufficient permissions" }, status: :forbidden
  end

  def teacher_can_manage_grade?
    return false unless teacher?
    teacher_id = current_user.teacher&.id
    return false unless teacher_id

    if @grade.present?
      @grade.course.teacher_id == teacher_id
    else
      course_id = params.dig(:grade, :course_id)
      return false unless course_id

      Course.exists?(id: course_id, teacher_id: teacher_id)
    end
  end
end
