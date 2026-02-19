class Api::V1::StudentsController < Api::V1::BaseController
  before_action :set_student, only: [:show, :update, :destroy]

  def index
    @students = Student.all
    render json: @students
  end

  def show
    render json: @student
  end

  def create
    @student = Student.new(student_params)
    
    # Validate semester (max 12)
    if @student.semester.present? && @student.semester > 12
      return render json: { error: "Semester cannot exceed 12" }, status: :unprocessable_entity
    end
    
    if @student.save
      render json: @student, status: :created
    else
      render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Validate semester (max 12)
    if student_params[:semester].present? && student_params[:semester].to_i > 12
      return render json: { error: "Semester cannot exceed 12" }, status: :unprocessable_entity
    end
    
    if @student.update(student_params)
      render json: @student
    else
      render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @student.destroy
      head :no_content
    else
      render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_student
    @student = Student.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def student_params
    params.require(:student).permit(:user_id, :department_id, :semester, :max_credit_hours, :max_credit_per_semester)
  end
end
