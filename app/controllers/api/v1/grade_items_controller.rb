class Api::V1::GradeItemsController < Api::V1::BaseController
  before_action :set_grade_item, only: [:show, :update, :destroy]

  def index
    @grade_items = GradeItem.includes(grade: [:student, :course])
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
end
