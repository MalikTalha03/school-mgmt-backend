class Api::V1::DepartmentsController < Api::V1::BaseController
  before_action :set_department, only: [:show, :update, :destroy]

  def index
    @departments = Department.includes(:courses, :teachers, :students).all
    render json: @departments.map { |dept| 
      dept.as_json.merge(
        courses_count: dept.courses.count,
        teachers_count: dept.teachers.count,
        students_count: dept.students.count
      )
    }
  end

  def show
    render json: @department.as_json.merge(
      courses: @department.courses.as_json(only: [:id, :title, :credit_hours]),
      teachers: @department.teachers.as_json(only: [:id, :user_id, :designation]),
      students: @department.students.as_json(only: [:id, :user_id, :semester])
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
    # Check for associated records
    errors = []
    
    if @department.courses.any?
      errors << "Has #{@department.courses.count} active courses"
    end
    
    if @department.teachers.any?
      errors << "Has #{@department.teachers.count} teachers"
    end
    
    if @department.students.any?
      errors << "Has #{@department.students.count} students"
    end
    
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
