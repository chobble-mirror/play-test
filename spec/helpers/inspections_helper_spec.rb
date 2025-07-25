require "rails_helper"

RSpec.describe InspectionsHelper, type: :helper do
  describe "#format_inspection_count" do
    it "formats the inspection count" do
      user = double("User", inspections: double("Inspections", count: 5))
      expect(helper.format_inspection_count(user)).to eq("5 inspections")
    end
  end

  describe "#inspection_tabs" do
    let(:user) { create(:user) }
    let(:inspection) { create(:inspection, user: user) }

    it "returns standard tabs for regular units" do
      tabs = helper.inspection_tabs(inspection)
      expect(tabs).to eq(%w[
        inspection
        user_height
        slide
        structure
        anchorage
        materials
        fan
        enclosed
        results
      ])
    end

    it "excludes enclosed tab when not needed" do
      inspection.update!(is_totally_enclosed: false)
      tabs = helper.inspection_tabs(inspection)
      expect(tabs).not_to include("enclosed")
    end

    it "excludes slide tab when not needed" do
      inspection.update!(has_slide: false)
      tabs = helper.inspection_tabs(inspection)
      expect(tabs).not_to include("slide")
    end
  end

  describe "#inspection_actions" do
    let(:user) { create(:user) }
    let(:admin_user) { create(:user, :admin) }
    let(:inspection) { create(:inspection, user: user) }
    let(:complete_inspection) do
      inspection = create(:inspection, :completed, user: user)
      inspection
    end

    context "for non-complete inspections" do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      it "includes edit and delete actions" do
        actions = helper.inspection_actions(inspection)

        expect(actions).to include(
          hash_including(label: I18n.t("inspections.buttons.update"))
        )
        expect(actions).to include(
          hash_including(
            label: I18n.t("inspections.buttons.delete"),
            method: :delete,
            danger: true
          )
        )
      end
    end

    context "for complete inspections with regular user" do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      it "includes appropriate actions for complete inspections" do
        actions = helper.inspection_actions(complete_inspection)

        expect(actions).not_to include(
          hash_including(label: I18n.t("inspections.buttons.update"))
        )
        expect(actions).not_to include(
          hash_including(label: I18n.t("inspections.buttons.delete"))
        )
        expect(actions).to include(
          hash_including(label: I18n.t("inspections.buttons.switch_to_in_progress"))
        )
        expect(actions).to include(
          hash_including(label: I18n.t("inspections.buttons.log"))
        )
      end
    end

    context "for complete inspections with admin user" do
      before do
        allow(helper).to receive(:current_user).and_return(admin_user)
      end

      it "includes same actions as regular users for complete inspections" do
        actions = helper.inspection_actions(complete_inspection)

        expect(actions).not_to include(
          hash_including(label: I18n.t("inspections.buttons.update"))
        )
        expect(actions).not_to include(
          hash_including(label: I18n.t("inspections.buttons.delete"))
        )
        expect(actions).to include(
          hash_including(label: I18n.t("inspections.buttons.switch_to_in_progress"))
        )
        expect(actions).to include(
          hash_including(label: I18n.t("inspections.buttons.log"))
        )
      end
    end
  end

  describe "#inspection_result_badge" do
    let(:inspection) { build(:inspection) }

    context "when inspection passed is true" do
      before { inspection.passed = true }

      it "returns a pass badge with i18n text" do
        result = helper.inspection_result_badge(inspection)
        expect(result).to include("pass-badge")
        expect(result).to include(I18n.t("inspections.status.pass"))
      end
    end

    context "when inspection passed is false" do
      before { inspection.passed = false }

      it "returns a fail badge with i18n text" do
        result = helper.inspection_result_badge(inspection)
        expect(result).to include("fail-badge")
        expect(result).to include(I18n.t("inspections.status.fail"))
      end
    end

    context "when inspection passed is nil" do
      before { inspection.passed = nil }

      it "returns a pending badge with i18n text" do
        result = helper.inspection_result_badge(inspection)
        expect(result).to include("pending-badge")
        expect(result).to include(I18n.t("inspections.status.pending"))
      end
    end
  end
end
