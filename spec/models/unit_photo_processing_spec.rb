require "rails_helper"

RSpec.describe "Unit Photo Processing", type: :model do
  let(:user) { create(:user) }
  let(:unit) { create(:unit, user: user) }

  describe "photo processing" do
    it "processes large images to maximum size and converts to JPEG" do
      # Attach a large test image
      large_image_path = Rails.root.join("spec", "fixtures", "files", "large_landscape.jpg")
      unit.photo.attach(
        io: File.open(large_image_path),
        filename: "large_landscape.jpg",
        content_type: "image/jpeg"
      )

      # Save to trigger processing
      unit.save!

      expect(unit.photo).to be_attached

      # Check that the file has been processed (not the original)
      image = PdfGeneratorService::ImageProcessor.create_image(unit.photo)

      # The large test image was 1600x1200, should be processed to fit within 1200px
      expect([image.width, image.height].max).to be <= ImageProcessorService::FULL_SIZE

      # File should be converted to JPEG and smaller than original
      expect(unit.photo.content_type).to eq("image/jpeg")
      expect(unit.photo.blob.byte_size).to be < 1.megabyte
    end

    it "bakes EXIF orientation into processed images" do
      # Attach an image that needs rotation
      rotated_image_path = Rails.root.join("spec", "fixtures", "files", "orientation_6_rotate_90_cw.jpg")
      unit.photo.attach(
        io: File.open(rotated_image_path),
        filename: "orientation_6_rotate_90_cw.jpg",
        content_type: "image/jpeg"
      )

      # Save to trigger processing
      unit.save!

      expect(unit.photo).to be_attached

      # The processed image should have orientation baked in
      image = PdfGeneratorService::ImageProcessor.create_image(unit.photo)

      # Original was 100x60 landscape with orientation 6 (90° rotation needed)
      # After processing, orientation is baked in: 60x100 portrait
      expect(image.width).to eq(60)
      expect(image.height).to eq(100)

      # Should NOT need orientation correction (it's baked in)
      expect(PdfGeneratorService::ImageOrientationProcessor.needs_orientation_correction?(image)).to be false
    end

    it "handles invalid uploads by detaching the file after processing" do
      # Try to attach a non-image file
      text_file_path = Rails.root.join("spec", "fixtures", "files", "test.txt")
      unit.photo.attach(
        io: File.open(text_file_path),
        filename: "test.txt",
        content_type: "text/plain"
      )

      # Save to trigger processing
      unit.save!

      # Photo should be detached due to processing failure
      expect(unit.photo).not_to be_attached
    end
  end
end
