class PdfGeneratorService
  class ImageProcessor
    include Configuration

    # Unified QR code generator for any entity
    def self.generate_qr_code_footer(pdf, entity)
      entity_type = entity.class.name.downcase
      qr_code_png = QrCodeService.generate_qr_code(entity)
      qr_code_temp_file = Tempfile.new(["qr_code_#{entity_type}_#{entity.id}_#{Process.pid}", ".png"])

      begin
        qr_code_temp_file.binmode
        qr_code_temp_file.write(qr_code_png)
        qr_code_temp_file.close

        # Calculate positions using PositionCalculator
        photo_entity = entity.is_a?(Inspection) ? entity.unit : entity
        qr_x, qr_y = PositionCalculator.qr_code_position(pdf.bounds.width)

        # Add entity photo first (so it's behind the QR code)
        add_entity_photo_footer(pdf, photo_entity, qr_x, qr_y)

        # Add QR code on top with transparency
        pdf.transparent(0.5) do
          qr_width, qr_height = PositionCalculator.qr_code_dimensions
          pdf.image qr_code_temp_file.path, at: [qr_x, qr_y], width: qr_width, height: qr_height
        end
      ensure
        qr_code_temp_file.close unless qr_code_temp_file.closed?
        qr_code_temp_file.unlink if File.exist?(qr_code_temp_file.path)
      end
    end

    # Process image to handle EXIF orientation data
    def self.process_image_with_orientation(attachment)
      image = create_image(attachment)
      ImageOrientationProcessor.process_with_orientation(image)
    end

    # Add entity photo in footer area (below QR code)
    def self.add_entity_photo_footer(pdf, entity, qr_x, qr_y)
      # Early return if entity is nil or photo is not properly loaded
      return unless entity&.photo

      # Check if attachment is loaded to avoid N+1
      attachment = entity.photo
      return unless attachment.blob

      # Create image object once and reuse it
      image = create_image(attachment)

      # Get original image dimensions
      original_width, original_height = ImageOrientationProcessor.get_dimensions(image)

      # Calculate photo dimensions maintaining aspect ratio
      photo_width, photo_height = PositionCalculator.footer_photo_dimensions(original_width, original_height)

      # Calculate position based on photo dimensions
      photo_x, photo_y = PositionCalculator.photo_footer_position(qr_x, qr_y, photo_width, photo_height)

      processed_image = ImageOrientationProcessor.process_with_orientation(image)
      pdf.image StringIO.new(processed_image), at: [photo_x, photo_y], width: photo_width, height: photo_height
    end

    def self.create_image(attachment)
      # Download blob data only once
      image_data = attachment.blob.download
      MiniMagick::Image.read(image_data)
    end
  end
end
