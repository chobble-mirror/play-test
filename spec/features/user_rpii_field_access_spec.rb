require "rails_helper"

RSpec.feature "User RPII Field Access Control", type: :feature do
  let(:admin_user) { create(:user, :admin, :without_company) }
  let(:regular_user) { create(:user, :without_company) }
  let(:target_user) { create(:user, rpii_inspector_number: "RPII-123") }

  describe "Admin user access" do
    before do
      sign_in(admin_user)
    end

    it "can see RPII inspector number field when editing users" do
      visit edit_user_path(target_user)

      expect(page).to have_field(I18n.t("users.forms.rpii_inspector_number"))
      expect(page).to have_field("user[rpii_inspector_number]", with: "RPII-123")
    end

    it "can update RPII inspector number" do
      visit edit_user_path(target_user)

      fill_in I18n.t("users.forms.rpii_inspector_number"), with: "RPII-456"
      click_button I18n.t("users.buttons.update_user")

      expect(page).to have_content(I18n.t("users.messages.user_updated"))
      target_user.reload
      expect(target_user.rpii_inspector_number).to eq("RPII-456")
    end

    it "can update RPII inspector number for existing users" do
      user_with_rpii = create(:user, rpii_inspector_number: "RPII-OLD")
      visit edit_user_path(user_with_rpii)

      expect(page).to have_field(I18n.t("users.forms.rpii_inspector_number"))
      fill_in I18n.t("users.forms.rpii_inspector_number"), with: "RPII-789"
      click_button I18n.t("users.buttons.update_user")

      expect(page).to have_content(I18n.t("users.messages.user_updated"))
      user_with_rpii.reload
      expect(user_with_rpii.rpii_inspector_number).to eq("RPII-789")
    end

    it "shows RPII field in new user registration form" do
      visit new_user_path

      expect(page).to have_field(I18n.t("users.forms.rpii_inspector_number"))
      expect(page).to have_field("user[rpii_inspector_number]")
    end
  end

  describe "Regular user access" do
    before do
      sign_in(regular_user)
    end

    it "cannot see RPII inspector number field when editing their own profile" do
      visit edit_user_path(regular_user)

      expect(page).not_to have_field(I18n.t("users.forms.rpii_inspector_number"))
      expect(page).not_to have_field("user[rpii_inspector_number]")
    end

    it "cannot access edit page for other users" do
      visit edit_user_path(target_user)

      expect(page).to have_current_path(root_path)
      expect(page).to have_content("You are not authorized to access this page")
    end

    it "cannot update RPII inspector number via form submission" do
      # Attempt to submit RPII data directly
      page.driver.submit :patch, user_path(regular_user), {
        user: {
          email: regular_user.email,
          rpii_inspector_number: "HACKED-999"
        }
      }

      regular_user.reload
      expect(regular_user.rpii_inspector_number).not_to eq("HACKED-999")
    end

    it "shows RPII field in new user registration form when logged out" do
      visit logout_path
      visit new_user_path

      expect(page).to have_field(I18n.t("users.forms.rpii_inspector_number"))
      expect(page).to have_field("user[rpii_inspector_number]")
    end
  end

  describe "Unauthenticated access" do
    it "shows RPII field in new user registration form" do
      visit new_user_path

      expect(page).to have_field(I18n.t("users.forms.rpii_inspector_number"))
      expect(page).to have_field("user[rpii_inspector_number]")
    end

    it "requires RPII data during registration" do
      visit new_user_path

      fill_in I18n.t("users.forms.email"), with: "newuser@example.com"
      fill_in I18n.t("users.forms.name"), with: "New Test User"
      fill_in I18n.t("users.forms.rpii_inspector_number"), with: "RPII-NEW-123"
      fill_in I18n.t("users.forms.password"), with: "password123"
      fill_in I18n.t("users.forms.password_confirmation"), with: "password123"

      click_button I18n.t("users.buttons.register")

      expect(page).to have_content(I18n.t("users.messages.account_created"))

      new_user = User.find_by(email: "newuser@example.com")
      expect(new_user).to be_present
      expect(new_user.rpii_inspector_number).to eq("RPII-NEW-123")
    end

    it "allows registration without RPII number" do
      visit new_user_path

      fill_in I18n.t("users.forms.email"), with: "newuser@example.com"
      fill_in I18n.t("users.forms.name"), with: "New Test User"
      fill_in I18n.t("users.forms.password"), with: "password123"
      fill_in I18n.t("users.forms.password_confirmation"), with: "password123"
      # Intentionally not filling RPII field

      click_button I18n.t("users.buttons.register")

      # Should successfully create account without RPII
      expect(page).to have_content(I18n.t("users.messages.account_created"))

      # Verify user was created without RPII
      new_user = User.find_by(email: "newuser@example.com")
      expect(new_user).to be_present
      expect(new_user.rpii_inspector_number).to be_nil
    end
  end
end
