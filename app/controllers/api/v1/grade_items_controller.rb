class Api::V1::GradeItemsController < Api::V1::BaseController
  before_action :set_grade_item, only: [ :show, :update, :destroy ]
  before_action -> { require_roles(:admin, :teacher) }, only: [ :create, :update, :destroy ]
  before_action :authorize_grade_item_read!, only: [ :show ]
  before_action :authorize_grade_item_write!, only: [ :create, :update, :destroy ]

  def index
    @grade_items = GradeItem.includes(grade: [ :student, :course ])
    @grade_items = if admin?
      @grade_items
    elsif student?
      student_record = current_user.student
      student_record ? @grade_items.joins(:grade).where(grades: { student_id: student_record.id }) : GradeItem.none
    elsif teacher?
      teacher_record = current_user.teacher
      teacher_record ? @grade_items.joins(grade: :course).where(courses: { teacher_id: teacher_record.id }) : GradeItem.none
    else
      GradeItem.none
    end

    render json: @grade_items, include: { grade: { include: [ :student, :course ] } }
  end

  def show
    render json: @grade_item, include: { grade: { include: [ :student, :course ] } }
  end

  def create
    @grade_item = GradeItem.new(grade_item_params)

    if @grade_item.save
      render json: @grade_item, status: :created
    else
      render json: { errors: @grade_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @grade_item.update(grade_item_params)
      render json: @grade_item
    else
      render json: { errors: @grade_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @grade_item.destroy
      head :no_content
    else
      render json: { errors: @grade_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_grade_item
    @grade_item = GradeItem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Grade item not found" }, status: :not_found
  end

  def grade_item_params
    params.require(:grade_item).permit(:grade_id, :category, :max_marks, :obtained_marks)
  end

  def authorize_grade_item_read!
    return if admin?
    return if student? && current_user.student&.id == @grade_item.grade.student_id
    return if teacher? && current_user.teacher&.id == @grade_item.grade.course.teacher_id

    render json: { error: "Forbidden: insufficient permissions" }, status: :forbidden
  end

  def authorize_grade_item_write!
    return if admin?
    return if teacher_can_manage_grade_item?

    render json: { error: "Forbidden: insufficient permissions" }, status: :forbidden
  end

  def teacher_can_manage_grade_item?
    return false unless teacher?
    teacher_id = current_user.teacher&.id
    return false unless teacher_id

    if @grade_item.present?
      @grade_item.grade.course.teacher_id == teacher_id
    else
      grade_id = params.dig(:grade_item, :grade_id)
      return false unless grade_id

      Grade.joins(:course).where(id: grade_id, courses: { teacher_id: teacher_id }).exists?
    end
  end
end
