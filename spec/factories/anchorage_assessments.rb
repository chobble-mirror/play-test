FactoryBot.define do
  factory :anchorage_assessment, class: "Assessments::AnchorageAssessment" do
    association :inspection

    # Anchor counts (defaults to nil for tests to control)
    num_low_anchors { nil }
    num_high_anchors { nil }

    # Pass/fail assessments
    num_low_anchors_pass { nil }
    num_high_anchors_pass { nil }
    anchor_type_pass { nil }
    pull_strength_pass { nil }
    anchor_degree_pass { nil }
    anchor_accessories_pass { nil }

    trait :passed do
      num_low_anchors { 6 }
      num_high_anchors { 4 }
      num_low_anchors_pass { true }
      num_high_anchors_pass { true }
      anchor_type_pass { true }
      pull_strength_pass { true }
      anchor_degree_pass { true }
      anchor_accessories_pass { true }
    end

    trait :complete do
      num_low_anchors { 6 }
      num_high_anchors { 4 }
      num_low_anchors_pass { true }
      num_high_anchors_pass { true }
      anchor_type_pass { true }
      pull_strength_pass { true }
      anchor_degree_pass { true }
      anchor_accessories_pass { true }
      num_low_anchors_comment { "Low anchor count appropriate" }
      num_high_anchors_comment { "High anchor count adequate" }
      anchor_type_comment { "Appropriate anchor type for surface" }
      pull_strength_comment { "Pull strength meets requirements" }
      anchor_degree_comment { "Anchor angle within specification" }
      anchor_accessories_comment { "All anchor accessories present" }
    end

    trait :failed do
      num_low_anchors { 2 }
      num_high_anchors { 1 }
      num_low_anchors_pass { false }
      num_high_anchors_pass { false }
      anchor_type_pass { false }
      pull_strength_pass { false }
      anchor_degree_pass { true }
      anchor_accessories_pass { true }
    end

    trait :critical_failures do
      anchor_type_pass { false }
      pull_strength_pass { false }
    end

    trait :insufficient_anchors do
      num_low_anchors { 1 }
      num_high_anchors { 1 }
      num_low_anchors_pass { false }
      num_high_anchors_pass { false }
    end
  end
end
