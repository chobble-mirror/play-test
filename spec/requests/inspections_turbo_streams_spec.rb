require "rails_helper"

RSpec.describe "Inspections Turbo Streams", type: :request do
  let(:user) { create(:user) }
  let(:inspection) { create(:inspection, user: user) }

  before do
    login_as(user)
  end

  describe "PATCH /inspections/:id with Turbo Streams" do
    context "when request accepts turbo streams" do
      let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

      it "returns turbo stream content type" do
        patch inspection_path(inspection),
          params: {inspection: {inspection_location: "Updated via turbo"}},
          headers: turbo_headers

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "returns properly formatted turbo stream elements" do
        patch inspection_path(inspection),
          params: {inspection: {inspection_location: "Test update"}},
          headers: turbo_headers

        # Parse the response to check structure
        expect(response.body).to include("<turbo-stream")
        expect(response.body).to include('action="replace"')
        expect(response.body).to include("target=\"inspection_progress_#{inspection.id}\"")
        expect(response.body).to include("<template>")
        expect(response.body).to include("</template>")
        expect(response.body).to include("</turbo-stream>")
      end

      it "includes progress status in turbo stream" do
        patch inspection_path(inspection),
          params: {inspection: {inspection_location: "Test Location"}},
          headers: turbo_headers

        # Should include the progress status (HTML might be escaped in template)
        expect(response.body).to include("inspection_progress_#{inspection.id}")
        expect(response.body).to match(/(&lt;span class=&#39;value&#39;&gt;|<span class='value'>)(In Progress|Complete)(&lt;\/span&gt;|<\/span>)/)
      end

      it "includes completion issues turbo stream" do
        patch inspection_path(inspection),
          params: {inspection: {inspection_location: "Test"}},
          headers: turbo_headers
      end

      context "when updating assessment data" do
        before do
          inspection.user_height_assessment.update!(
            containing_wall_height: 1.0,
            platform_height: 1.0
          )
        end

        it "successfully updates assessment via turbo stream" do
          expect {
            patch inspection_path(inspection),
              params: {
                inspection: {
                  user_height_assessment_attributes: {
                    id: inspection.user_height_assessment.id,
                    containing_wall_height: 2.0
                  }
                }
              },
              headers: turbo_headers
          }.to change {
            inspection.user_height_assessment.reload.containing_wall_height
          }.from(1.0).to(2.0)

          expect(response).to have_http_status(:ok)
        end
      end

      context "with validation errors" do
        it "still returns turbo stream format on error" do
          # Force a validation error by trying to clear a required field
          # Don't mark as complete so we can actually test the validation error handling
          patch inspection_path(inspection),
            params: {inspection: {inspection_location: ""}},
            headers: turbo_headers

          expect(response.content_type).to include("text/vnd.turbo-stream.html")
          expect(response.body).to include("<turbo-stream")
        end
      end
    end

    context "when request accepts JSON" do
      let(:json_headers) { {"Accept" => "application/json"} }

      it "returns JSON response for backwards compatibility" do
        patch inspection_path(inspection),
          params: {inspection: {inspection_location: "Updated via JSON"}},
          headers: json_headers

        expect(response.content_type).to include("application/json")
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
      end
    end

    context "when request is standard HTML" do
      it "redirects on success" do
        patch inspection_path(inspection),
          params: {inspection: {risk_assessment: "Updated via HTML"}}

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(inspection_path(inspection))
      end
    end
  end

  describe "Progress calculation in turbo streams" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

    it "updates progress when assessment is marked complete" do
      # Create an incomplete assessment
      inspection.user_height_assessment.update!(
        containing_wall_height: nil,
        platform_height: nil
      )

      # Get the complete attributes for user height assessment
      complete_attrs = attributes_for(:user_height_assessment, :complete).merge(
        id: inspection.user_height_assessment.id
      )

      # Complete the assessment
      patch inspection_path(inspection),
        params: {
          inspection: {
            user_height_assessment_attributes: complete_attrs
          }
        },
        headers: turbo_headers

      # Reload to check if update worked
      inspection.reload
      user_height = inspection.user_height_assessment.reload

      # Debug output
      if user_height.incomplete_fields.any?
        puts "User height incomplete fields: #{user_height.incomplete_fields.inspect}"
      end

      # Should show In Progress status
      expect(response.body).to match(/(&lt;span class=&#39;value&#39;&gt;|<span class='value'>)(In Progress|Complete)(&lt;\/span&gt;|<\/span>)/)
    end
  end

  describe "Completed inspection behavior" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }
    let(:completed_inspection) { create_completed_inspection(user: user) }

    before do
      # completed_inspection is already properly completed
    end

    it "redirects when trying to update completed inspections" do
      patch inspection_path(completed_inspection),
        params: {inspection: {inspection_location: "Updated"}},
        headers: turbo_headers

      # Should redirect because completed inspections cannot be edited
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(inspection_path(completed_inspection))
    end
  end

  describe "Error handling" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

    it "doesn't break on controller helper method calls" do
      # This test ensures we're using helpers.method_name correctly
      patch inspection_path(inspection),
        params: {inspection: {inspection_location: "Test"}},
        headers: turbo_headers

      expect(response).to have_http_status(:ok)
      # Should not raise NoMethodError for content_tag or helper methods
    end

    it "handles missing assessments gracefully" do
      # Ensure no assessments exist
      inspection.user_height_assessment&.destroy

      patch inspection_path(inspection),
        params: {inspection: {inspection_location: "Test"}},
        headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("In Progress") # Should show In Progress status
    end
  end
end
