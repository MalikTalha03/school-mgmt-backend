class Api::V1::TeachersController < Api::V1::BaseController
  before_action :set_teacher, only: [:show, :update, :destroy]
  before_action :authenticate_user!

  def index
    @teachers = Teacher.includes(:department, :courses).all
    render json: @teachers
  end

  def show
    render json: @teacher
  end

  def create
    @teacher = Teacher.new(teacher_params)
    
    if @teacher.save
      render json: @teacher, status: :created
    else
      render json: { errors: @teacher.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @teacher.update(teacher_params)
      render json: @teacher
    else
      render json: { errors: @teacher.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Check if teacher has active courses
    if @teacher.courses.any?
      return render json: { error: "Cannot delete teacher with active courses. Please reassign or remove courses first." }, status: :unprocessable_entity
    end
    
    if @teacher.destroy
      head :no_content
    else
      render json: { errors: @teacher.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_teacher
    @teacher = Teacher.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Teacher not found" }, status: :not_found
  end

  def teacher_params
    params.require(:teacher).permit(:user_id, :department_id, :designation)
  end
end
