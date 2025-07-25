require "rails_helper"

RSpec.describe "Assessment Safety Calculations", type: :request do
  let(:user) { create(:user) }
  let(:inspection) { create(:inspection, user: user) }
  let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

  before { login_as(user) }

  describe "dynamic calculations" do
    it "updates anchorage calculations" do
      # Set inspection dimensions so calculations can be performed
      inspection.update!(width: 10, height: 5, length: 15)

      patch inspection_anchorage_assessment_path(inspection),
        params: {
          assessments_anchorage_assessment: {
            num_low_anchors: 4,
            num_high_anchors: 3
          }
        },
        headers: turbo_headers

      expect(response.body).to include("7") # Total anchors
    end

    it "updates slide runout calculations" do
      inspection.slide_assessment.update!(slide_platform_height: 2.0)

      patch inspection_slide_assessment_path(inspection),
        params: {
          assessments_slide_assessment: {
            runout: 1.5
          }
        },
        headers: turbo_headers

      expect(response.body).to include("slide_safety_results")
    end

    it "updates user height calculations" do
      # First set platform_height on structure assessment
      inspection.structure_assessment.update!(platform_height: 2.0)

      patch inspection_user_height_assessment_path(inspection),
        params: {
          assessments_user_height_assessment: {
            containing_wall_height: 1,
            tallest_user_height: 1.99
          }
        },
        headers: turbo_headers

      expect(response.body).to include("Height Requirements")
      expect(response.body).to include("1.99m")
    end
  end
end
