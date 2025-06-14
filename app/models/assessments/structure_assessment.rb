class Assessments::StructureAssessment < ApplicationRecord
  include AssessmentLogging
  include SafetyCheckMethods
  include AssessmentCompletion

  belongs_to :inspection

  # Critical safety checks
  CRITICAL_CHECKS = %w[seam_integrity_pass uses_lock_stitching_pass air_loss_pass
    straight_walls_pass sharp_edges_pass unit_stable_pass].freeze

  # Additional pass/fail checks
  ADDITIONAL_CHECKS = %w[stitch_length_pass blower_tube_length_pass
    step_ramp_size_pass critical_fall_off_height_pass unit_pressure_pass
    trough_depth_pass trough_adjacent_panel_width_pass trough_pass entrapment_pass markings_pass grounding_pass].freeze

  # Required measurements
  REQUIRED_MEASUREMENTS = %w[stitch_length unit_pressure blower_tube_length].freeze

  # Pass/fail checks for measurements
  MEASUREMENT_CHECKS = %w[stitch_length_pass unit_pressure_pass blower_tube_length_pass].freeze

  # Measurements
  validates :stitch_length, :unit_pressure, :blower_tube_length,
    :step_ramp_size, :critical_fall_off_height, :trough_depth, :trough_adjacent_panel_width,
    numericality: {greater_than_or_equal_to: 0}, allow_blank: true

  # Callbacks
  after_update :log_assessment_update, if: :saved_changes?

  def measurement_compliance
    {
      stitch_length: stitch_length_compliant?,
      unit_pressure: unit_pressure_compliant?,
      blower_tube_distance: blower_tube_distance_compliant?,
      fall_off_height: fall_off_height_compliant?
    }
  end

  private

  def stitch_length_compliant?
    SafetyStandard.valid_stitch_length?(stitch_length)
  end

  def unit_pressure_compliant?
    SafetyStandard.valid_pressure?(unit_pressure)
  end

  def blower_tube_distance_compliant?
    blower_tube_length.present? && blower_tube_length >= 1.2 # 1.2m minimum
  end

  def fall_off_height_compliant?
    SafetyStandard.valid_fall_height?(critical_fall_off_height)
  end

  def log_assessment_update
    inspection.log_audit_action("assessment_updated", inspection.user, "Structure Assessment updated")
  end
end
