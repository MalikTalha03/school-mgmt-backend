class Api::V1::TeachersController < Api::V1::BaseController
  before_action :set_teacher, only: [:show, :update, :destroy]

  def index
    @teachers = Teacher.includes(:department, :user, :courses).all
    render json: @teachers, include: [:department, :user]
  end

  def show
    render json: @teacher, include: [:department, :user, :courses]
  end

  def create
    # Extract user creation params
    name = params[:teacher][:name]
    department_id = params[:teacher][:department_id]
    designation = params[:teacher][:designation]

    if name.blank?
      return render json: { error: "Name is required" }, status: :unprocessable_entity
    end

    if department_id.blank?
      return render json: { error: "Department is required" }, status: :unprocessable_entity
    end

    # Generate unique email
    base_email = generate_teacher_email(name, department_id)
    email = ensure_unique_email(base_email)

    # Create user with default password
    user = User.new(
      email: email,
      password: '12345678',
      password_confirmation: '12345678',
      role: :teacher,
      name: name
    )

    if user.save
      # Create teacher record
      @teacher = Teacher.new(
        user_id: user.id,
        department_id: department_id,
        designation: designation
      )

      if @teacher.save
        render json: @teacher.as_json(include: [:department, :user]), status: :created
      else
        user.destroy # Rollback user creation
        render json: { errors: @teacher.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
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
    params.require(:teacher).permit(:user_id, :department_id, :designation, :name)
  end

  def generate_teacher_email(name, department_id)
    # Clean name: remove spaces, special chars, convert to lowercase
    clean_name = name.downcase.gsub(/[^a-z0-9]/, '')
    
    # Get department code
    dept = Department.find_by(id: department_id)
    dept_code = dept&.code&.downcase || 'dept'
    
    "#{clean_name}@#{dept_code}.edu"
  end

  def ensure_unique_email(base_email)
    email = base_email
    counter = 1
    
    while User.exists?(email: email)
      # Split email into name and domain
      name_part = base_email.split('@').first
      domain_part = base_email.split('@').last
      email = "#{name_part}#{counter}@#{domain_part}"
      counter += 1
    end
    
    email
  end
end
