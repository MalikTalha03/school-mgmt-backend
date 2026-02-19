class Api::V1::GradeItemsController < Api::V1::BaseController
  before_action :set_grade_item, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  before_action :validate_final_prerequisites, only: [:create, :update]

  def index
    @grade_items = GradeItem.includes(grade: [:student, :course]).all
    render json: @grade_items, include: { grade: { include: [:student, :course] } }
  end

  def show
    render json: @grade_item, include: { grade: { include: [:student, :course] } }
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

  def validate_final_prerequisites
    return unless params[:grade_item][:category] == 'final' || params[:grade_item][:category] == '3'
    
    grade_id = params[:grade_item][:grade_id] || @grade_item&.grade_id
    return unless grade_id
    
    grade = Grade.find_by(id: grade_id)
    return unless grade
    
    has_midterm = grade.grade_items.exists?(category: :midterm)
    has_assignment = grade.grade_items.exists?(category: :assignment)
    has_quiz = grade.grade_items.exists?(category: :quiz)
    
    # When updating, check if this is the existing final
    if @grade_item&.final?
      return
    end
    
    unless has_midterm && has_assignment && has_quiz
      missing = []
      missing << 'midterm' unless has_midterm
      missing << 'assignment' unless has_assignment
      missing << 'quiz' unless has_quiz
      
      render json: { 
        error: "Cannot enter final marks without required grade items",
        missing: missing,
        requirement: "Must have at least 1 midterm, 1 assignment, and 1 quiz"
      }, status: :unprocessable_entity
    end
  end
end
