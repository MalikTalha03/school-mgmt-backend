class Api::V1::StudentsController < Api::V1::BaseController
  before_action :set_student, only: [:show, :update, :destroy, :promote_semester]
  before_action :authenticate_user!
  before_action :require_admin!, only: [:promote_semester]

  def index
    @students = Student.includes(:department, :user).all
    render json: @students, include: [:department, :user]
  end

  def show
    render json: @student, include: [:department, :user]
  end

  def create
    # Extract user creation params
    name = params[:student][:name]
    department_id = params[:student][:department_id]
    semester = params[:student][:semester] || 1

    if name.blank?
      return render json: { error: "Name is required" }, status: :unprocessable_entity
    end

    if department_id.blank?
      return render json: { error: "Department is required" }, status: :unprocessable_entity
    end

    # Validate semester (max 12)
    if semester.to_i > 12 || semester.to_i < 1
      return render json: { error: "Semester must be between 1 and 12" }, status: :unprocessable_entity
    end

    # Generate unique email
    base_email = generate_student_email(name, department_id)
    email = ensure_unique_email(base_email)

    # Create user with default password
    user = User.new(
      email: email,
      password: '12345678',
      password_confirmation: '12345678',
      role: :student,
      name: name
    )

    if user.save
      # Create student record
      @student = Student.new(
        user_id: user.id,
        department_id: department_id,
        semester: semester
      )

      if @student.save
        render json: @student.as_json(include: [:department, :user]), status: :created
      else
        user.destroy # Rollback user creation
        render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
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

  def promote_semester
    if @student.can_promote_to_next_semester?
      if @student.promote_to_next_semester!
        @student.reload
        render json: @student, include: [:department, :user]
      else
        render json: { error: "Failed to promote student", errors: @student.errors.full_messages }, status: :unprocessable_entity
      end
    else
      active_count = @student.enrollments.where(status: :approved).count
      pending_count = @student.enrollments.where(status: :pending).count
      
      reasons = []
      reasons << "Student has #{active_count} active enrollment(s)" if active_count > 0
      reasons << "Student has #{pending_count} pending enrollment(s)" if pending_count > 0
      reasons << "Student is already in final semester (12)" if @student.semester && @student.semester >= 12
      
      render json: { 
        error: "Cannot promote student to next semester", 
        reasons: reasons,
        active_enrollments: active_count,
        pending_enrollments: pending_count,
        current_semester: @student.semester
      }, status: :unprocessable_entity
    end
  end

  private

  def set_student
    @student = Student.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def require_admin!
    unless current_user&.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end

  def student_params
    params.require(:student).permit(:user_id, :department_id, :semester, :max_credit_hours, :max_credit_per_semester, :name)
  end

  def generate_student_email(name, department_id)
    # Clean name: remove spaces, special chars, convert to lowercase
    clean_name = name.downcase.gsub(/[^a-z0-9]/, '')
    
    # Get department code
    dept = Department.find_by(id: department_id)
    dept_code = dept&.code&.downcase || 'dept'
    
    "#{clean_name}@#{dept_code}.student.edu"
  end

  def ensure_unique_email(base_email)
    email = base_email
    counter = 1
    
    while User.exists?(email: email)
      # Split email into name and domain
      name_part = base_email.split('@').first
      domain_part = base_email.split('@')[1..-1].join('@')
      email = "#{name_part}#{counter}@#{domain_part}"
      counter += 1
    end
    
    email
  end
end
