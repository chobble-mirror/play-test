require "rails_helper"

RSpec.describe SafetyStandard, "Constants" do
  describe "ANCHOR_CALCULATION_CONSTANTS" do
    it "defines expected anchor calculation values" do
      constants = SafetyStandard::ANCHOR_CALCULATION_CONSTANTS

      expect(constants[:area_coefficient]).to eq(114.0)
      expect(constants[:base_divisor]).to eq(1600.0)
      expect(constants[:safety_factor]).to eq(1.5)
    end

    it "is used in anchor calculations" do
      # Verify the calculation uses these exact constant values
      area = 25.0
      expected = ((area**2 * 114.0) / 1600.0 * 1.5).ceil

      result = SafetyStandard.calculate_required_anchors(area)
      expect(result).to eq(expected)
      expect(result).to eq(67) # Known result for 25m²
    end
  end

  describe "USER_SPACE_REQUIREMENTS" do
    it "defines expected user space values" do
      constants = SafetyStandard::USER_SPACE_REQUIREMENTS

      expect(constants[:young_children_1000mm]).to eq(1.5)
      expect(constants[:children_1200mm]).to eq(2.0)
      expect(constants[:adolescents_1500mm]).to eq(2.5)
      expect(constants[:adults_1800mm]).to eq(3.0)
    end

    it "is used in user capacity calculations" do
      length, width = 5.0, 4.0
      usable_area = 18.0 # (5 * 4) - 2
      negative_adjustment = 2.0

      result = SafetyStandard.calculate_user_capacity(length, width, negative_adjustment)

      # Verify calculations use the exact constant values
      expect(result[:users_1000mm]).to eq((usable_area / 1.5).floor)
      expect(result[:users_1200mm]).to eq((usable_area / 2.0).floor)
      expect(result[:users_1500mm]).to eq((usable_area / 2.5).floor)
      expect(result[:users_1800mm]).to eq((usable_area / 3.0).floor)
    end
  end

  describe "RUNOUT_CALCULATION_CONSTANTS" do
    it "defines expected runout calculation values" do
      constants = SafetyStandard::RUNOUT_CALCULATION_CONSTANTS

      expect(constants[:platform_height_ratio]).to eq(0.5)
      expect(constants[:minimum_runout_meters]).to eq(0.3)
    end

    it "is used in runout calculations" do
      platform_height = 2.5
      expected = [platform_height * 0.5, 0.3].max

      result = SafetyStandard.calculate_required_runout(platform_height)
      expect(result).to eq(expected)
      expect(result).to eq(1.25)
    end
  end

  describe "WALL_HEIGHT_CONSTANTS" do
    it "defines expected wall height multiplier" do
      constants = SafetyStandard::WALL_HEIGHT_CONSTANTS

      expect(constants[:enhanced_height_multiplier]).to eq(1.25)
    end

    it "is used in wall height calculations" do
      user_height = 4.0 # In the enhanced walls range
      containing_wall_height = 5.0 # 4.0 * 1.25 = 5.0

      result = SafetyStandard.meets_height_requirements?(user_height, containing_wall_height)
      expect(result).to be true

      # Test that it fails with insufficient wall height
      insufficient_wall = 4.9 # Just under 4.0 * 1.25
      result = SafetyStandard.meets_height_requirements?(user_height, insufficient_wall)
      expect(result).to be false
    end
  end

  describe "source code transparency" do
    it "includes constants in method source display" do
      source = SafetyStandard.get_method_source(:calculate_required_anchors)

      # Verify constants are shown
      expect(source).to include("ANCHOR_CALCULATION_CONSTANTS")
      expect(source).to include("area_coefficient: 114.0")
      expect(source).to include("base_divisor: 1600.0")
      expect(source).to include("safety_factor: 1.5")

      # Verify method implementation is shown
      expect(source).to include("def calculate_required_anchors")
      expect(source).to include("ANCHOR_CALCULATION_CONSTANTS[:area_coefficient]")
    end

    it "shows multiple constants for methods that use them" do
      source = SafetyStandard.get_method_source(:meets_height_requirements?)

      # Should include both constant definitions
      expect(source).to include("SLIDE_HEIGHT_THRESHOLDS")
      expect(source).to include("WALL_HEIGHT_CONSTANTS")
      expect(source).to include("enhanced_height_multiplier: 1.25")
    end
  end

  describe "no magic numbers remain" do
    it "uses constants throughout the codebase" do
      # Verify no hardcoded magic numbers in key calculations
      source_file = File.read(Rails.root.join("app/models/safety_standard.rb"))

      # These magic numbers should no longer appear in calculation methods
      # (except in the constants definitions themselves)
      calculation_methods = source_file.split(/def calculate_|def meets_height_|def valid_|def requires_/)[1..]

      calculation_methods.each do |method_content|
        method_lines = method_content.split("\n")
        next if method_lines.empty?

        # Skip the method that just defines constants
        next if method_lines.first.include?("calculation_metadata")

        # Check that magic numbers aren't hardcoded in calculations
        expect(method_content).not_to include("* 114.0"), "Found hardcoded 114.0 in calculation method"
        expect(method_content).not_to include("/ 1600.0"), "Found hardcoded 1600.0 in calculation method"
        expect(method_content).not_to include("* 1.5"), "Found hardcoded 1.5 in calculation method (outside comments)"
        expect(method_content).not_to include("/ 1.5"), "Found hardcoded 1.5 in calculation method"
        expect(method_content).not_to include("/ 2.0"), "Found hardcoded 2.0 in calculation method"
        expect(method_content).not_to include("/ 2.5"), "Found hardcoded 2.5 in calculation method"
        expect(method_content).not_to include("/ 3.0"), "Found hardcoded 3.0 in calculation method"
        expect(method_content).not_to include("* 0.5"), "Found hardcoded 0.5 in calculation method"
        expect(method_content).not_to include(">= 1.0"), "Found hardcoded 1.0 in validation method"
        expect(method_content).not_to include("<= 0.6"), "Found hardcoded 0.6 in validation method"
        expect(method_content).not_to include("between?(3, 8)"), "Found hardcoded 3,8 in validation method"
        expect(method_content).not_to include("between?(18, 45)"), "Found hardcoded 18,45 in validation method"
        expect(method_content).not_to include("> 15"), "Found hardcoded 15 in validation method"
      end
    end

    it "validates new constants exist and are used" do
      # Check new constants are defined
      expect(SafetyStandard::MATERIAL_STANDARDS).to be_present
      expect(SafetyStandard::EQUIPMENT_SAFETY_LIMITS).to be_present
      expect(SafetyStandard::GROUNDING_TEST_WEIGHTS).to be_present
      expect(SafetyStandard::REINSPECTION_INTERVAL_DAYS).to eq(365)

      # Check validation methods use constants
      expect(SafetyStandard.valid_stitch_length?(5)).to be true
      expect(SafetyStandard.valid_stitch_length?(2)).to be false # Below min
      expect(SafetyStandard.valid_stitch_length?(9)).to be false # Above max

      expect(SafetyStandard.valid_pressure?(1.5)).to be true
      expect(SafetyStandard.valid_pressure?(0.5)).to be false # Below min

      expect(SafetyStandard.requires_multiple_exits?(20)).to be true
      expect(SafetyStandard.requires_multiple_exits?(10)).to be false # Below threshold
    end

    it "generates consistent formula descriptions from constants" do
      anchor_metadata = SafetyStandard.calculation_metadata[:anchors]
      runout_metadata = SafetyStandard.calculation_metadata[:slide_runout]

      # Formula text should include actual constant values
      expect(anchor_metadata[:formula_text]).to include("114.0")
      expect(anchor_metadata[:formula_text]).to include("1600.0")
      expect(anchor_metadata[:formula_text]).to include("1.5")

      expect(runout_metadata[:formula_text]).to include("50%")
      expect(runout_metadata[:formula_text]).to include("300mm")
    end
  end
end
