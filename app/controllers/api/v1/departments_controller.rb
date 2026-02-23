class Api::V1::DepartmentsController < Api::V1::BaseController
  before_action :set_department, only: [ :show, :update, :destroy ]

  def index
    @departments = Department.includes(:courses, :teachers, :students).all
    render json: @departments.map { |dept|
      dept.as_json.merge(
        courses_count: dept.courses.size,
        teachers_count: dept.teachers.size,
        students_count: dept.students.size
      )
    }
  end

  def show
    render json: @department.as_json.merge(
      courses: @department.courses.as_json(only: [ :id, :title, :credit_hours ]),
      teachers: @department.teachers.as_json(only: [ :id, :user_id, :designation ]),
      students: @department.students.as_json(only: [ :id, :user_id, :semester ])
    )
  end

  def create
    @department = Department.new(department_params)

    if @department.save
      render json: @department, status: :created
    else
      render json: { errors: @department.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      render json: @department
    else
      render json: { errors: @department.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Check for associated records — count each association once (avoids 3 extra .any? queries)
    courses_count  = @department.courses.count
    teachers_count = @department.teachers.count
    students_count = @department.students.count

    errors = []
    errors << "Has #{courses_count} active courses"  if courses_count  > 0
    errors << "Has #{teachers_count} teachers"        if teachers_count > 0
    errors << "Has #{students_count} students"        if students_count > 0

    unless errors.empty?
      return render json: {
        error: "Cannot delete department with associated records",
        details: errors,
        suggestion: "Please reassign or remove all associated records first"
      }, status: :unprocessable_entity
    end

    if @department.destroy
      head :no_content
    else
      render json: { errors: @department.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Department not found" }, status: :not_found
  end

  def department_params
    params.require(:department).permit(:name, :code)
  end
end
