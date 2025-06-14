class Assessments::AnchorageAssessment < ApplicationRecord
  include AssessmentLogging
  include SafetyCheckMethods
  include AssessmentCompletion

  belongs_to :inspection

  # Anchor counts (alphabetical order)
  validates :num_high_anchors, :num_low_anchors,
    numericality: {greater_than_or_equal_to: 0, only_integer: true},
    allow_blank: true

  # Callbacks
  after_update :log_assessment_update, if: :saved_changes?
  after_save :update_anchor_calculations, if: :saved_change_to_anchor_counts?

  def meets_anchor_requirements?
    return false unless total_anchors.present? && inspection.area.present?

    inspection_area = inspection.area
    required_anchors = SafetyStandard.calculate_required_anchors(inspection_area)
    total_anchors >= required_anchors
  end

  def total_anchors
    (num_low_anchors || 0) + (num_high_anchors || 0)
  end

  def required_anchors
    return 0 unless inspection.area.present?
    SafetyStandard.calculate_required_anchors(inspection.area)
  end

  def anchor_compliance_status
    return "Not Assessed" unless total_anchors.present?

    if meets_anchor_requirements?
      "Compliant"
    else
      required = required_anchors
      actual = total_anchors
      "Non-Compliant (Requires #{required} total anchors, has #{actual})"
    end
  end

  def anchor_distribution
    return {} unless num_low_anchors.present? && num_high_anchors.present?

    {
      low_anchors: num_low_anchors,
      high_anchors: num_high_anchors,
      total: total_anchors,
      required: required_anchors,
      percentage_low: (num_low_anchors.to_f / total_anchors * 100).round(1),
      percentage_high: (num_high_anchors.to_f / total_anchors * 100).round(1)
    }
  end

  def anchor_safety_summary
    issues = []

    issues << "Insufficient total anchors" unless meets_anchor_requirements?
    issues << "Anchor type non-compliant" if anchor_type_pass == false
    issues << "Pull strength insufficient" if pull_strength_pass == false
    issues << "Anchor angle incorrect" if anchor_degree_pass == false
    issues << "Missing anchor accessories" if anchor_accessories_pass == false

    issues.empty? ? "All anchor requirements met" : issues.join(", ")
  end

  private

  def saved_change_to_anchor_counts?
    saved_change_to_num_low_anchors? || saved_change_to_num_high_anchors?
  end

  def anchor_counts_present?
    num_low_anchors.present? && num_high_anchors.present?
  end

  def update_anchor_calculations
    # Auto-update anchor pass fields based on calculations
    if anchor_counts_present? && inspection.area.present?
      meets_requirements = meets_anchor_requirements?
      update_columns(
        num_low_anchors_pass: meets_requirements,
        num_high_anchors_pass: meets_requirements
      )
    end
  end
end
