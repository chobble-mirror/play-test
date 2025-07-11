class SafetyStandardsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :verify_authenticity_token, only: [:index]

  CALCULATION_TYPES = %w[anchors slide_runout wall_height user_capacity].freeze

  def index
    @calculation_metadata = SafetyStandard.calculation_metadata

    if post_request_with_calculation?
      handle_calculation_post
    else
      handle_calculation_get
    end
  end

  private

  def post_request_with_calculation?
    request.post? && params[:calculation].present?
  end

  def handle_calculation_post
    calculate_safety_standard
    respond_to do |format|
      format.turbo_stream
      format.json { render json: build_json_response }
      format.html { redirect_with_calculation_params }
    end
  end

  def handle_calculation_get
    calculate_safety_standard if params[:calculation].present?
    respond_to do |format|
      format.html
    end
  end

  def redirect_with_calculation_params
    redirect_to safety_standards_path(calculation: params[:calculation].to_unsafe_h)
  end

  def calculate_safety_standard
    type = params[:calculation][:type]
    send("calculate_#{type}") if CALCULATION_TYPES.include?(type)
  end

  def calculate_anchors
    dimensions = extract_dimensions(:length, :width, :height)

    if dimensions.values.all?(&:positive?)
      @anchor_result = SafetyStandards::AnchorCalculator.calculate(**dimensions)
    else
      set_error(:anchor, :invalid_dimensions)
    end
  end

  def calculate_slide_runout
    height = param_to_float(:platform_height)
    has_stop_wall = params[:calculation][:has_stop_wall] == "1"

    if height.positive?
      @runout_result = build_runout_result(height, has_stop_wall)
    else
      set_error(:runout, :invalid_height)
    end
  end

  def calculate_wall_height
    platform_height = param_to_float(:platform_height)
    user_height = param_to_float(:user_height)

    if platform_height.positive? && user_height.positive?
      @wall_height_result = build_wall_height_result(platform_height, user_height)
    else
      set_error(:wall_height, :invalid_height)
    end
  end

  def calculate_user_capacity
    length = param_to_float(:length)
    width = param_to_float(:width)
    max_user_height = param_to_float(:max_user_height)
    max_user_height = nil if max_user_height.zero?
    negative_adjustment_area = param_to_float(:negative_adjustment_area)

    if length.positive? && width.positive?
      @capacity_result = SafetyStandards::UserCapacityCalculator.calculate(
        length, width, max_user_height, negative_adjustment_area
      )
    else
      @capacity_result = nil
      @capacity_error = t("safety_standards.errors.invalid_dimensions")
    end
  end

  def extract_dimensions(*keys)
    keys.index_with { |key| param_to_float(key) }
  end

  def param_to_float(key)
    params[:calculation][key].to_f
  end

  def set_error(type, error_key)
    instance_variable_set("@#{type}_error", t("safety_standards.errors.#{error_key}"))
  end

  def build_runout_result(platform_height, has_stop_wall)
    SafetyStandards::SlideCalculator.calculate_required_runout(
      platform_height,
      has_stop_wall: has_stop_wall
    )
  end

  def build_wall_height_result(platform_height, user_height)
    SafetyStandards::SlideCalculator.calculate_wall_height_requirements(platform_height, user_height)
  end

  def build_json_response
    type = params[:calculation][:type]

    unless CALCULATION_TYPES.include?(type)
      return {
        passed: false,
        status: "Invalid calculation type: #{type || "none provided"}",
        result: nil
      }
    end

    build_typed_json_response(type)
  rescue => e
    {
      passed: false,
      status: "Calculation failed: #{e.message}",
      result: nil
    }
  end

  def build_typed_json_response(type)
    # Ensure calculation is performed
    calculate_safety_standard

    result_var = case type
    when "anchors" then "@anchor_result"
    when "slide_runout" then "@runout_result"
    when "wall_height" then "@wall_height_result"
    when "user_capacity" then "@capacity_result"
    end

    error_var = case type
    when "anchors" then "@anchor_error"
    when "slide_runout" then "@runout_error"
    when "wall_height" then "@wall_height_error"
    when "user_capacity" then "@capacity_error"
    end

    result = instance_variable_get(result_var)
    error = instance_variable_get(error_var)

    if result
      # For user capacity, we need to extract the capacities from the CalculatorResponse
      if type == "user_capacity" && result.is_a?(CalculatorResponse)
        capacities = result.value
        # Extract input parameters for backwards compatibility
        length = param_to_float(:length)
        width = param_to_float(:width)
        max_user_height = param_to_float(:max_user_height)
        max_user_height = nil if max_user_height.zero?
        negative_adjustment_area = param_to_float(:negative_adjustment_area)

        json_result = {
          length: length,
          width: width,
          area: (length * width).round(2),
          negative_adjustment_area: negative_adjustment_area,
          usable_area: [(length * width) - negative_adjustment_area, 0].max.round(2),
          max_user_height: max_user_height,
          capacities: capacities,
          breakdown: result.breakdown
        }
      else
        json_result = result
      end

      {
        passed: true,
        status: "Calculation completed successfully",
        result: json_result
      }
    else
      {
        passed: false,
        status: error || "Calculation failed with unknown error",
        result: nil
      }
    end
  end
end
