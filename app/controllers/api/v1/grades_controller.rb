class Api::V1::GradesController < Api::V1::BaseController
  before_action :set_grade, only: [ :show, :update, :destroy ]
  before_action :validate_grade_prerequisites, only: [ :create ]

  def index
    @grades = Grade.includes(:student, :course, :grade_items)
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
end
