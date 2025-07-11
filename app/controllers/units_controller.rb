class UnitsController < ApplicationController
  include UnitTurboStreams
  include PublicViewable
  include UserActivityCheck

  skip_before_action :require_login, only: %i[show]
  before_action :set_unit, only: %i[destroy edit log show update]
  before_action :check_unit_owner, only: %i[destroy edit update]
  before_action :check_log_access, only: %i[log]
  before_action :require_user_active, only: %i[create new edit update]
  before_action :no_index

  def index
    @units = filtered_units_query
    @title = build_index_title

    respond_to do |format|
      format.html
      format.csv do
        log_unit_event("exported", nil, "Exported #{@units.count} units to CSV")
        csv_data = UnitCsvExportService.new(@units).generate
        send_data csv_data, filename: "units-#{Time.zone.today}.csv"
      end
    end
  end

  def show
    @inspections = @unit.inspections
      .includes(inspector_company: {logo_attachment: :blob})
      .order(inspection_date: :desc)

    respond_to do |format|
      format.html { render_show_html }
      format.pdf { send_unit_pdf }
      format.png { send_unit_qr_code }
      format.json do
        render json: JsonSerializerService.serialize_unit(@unit)
      end
    end
  end

  def new = @unit = Unit.new

  def create
    @unit = current_user.units.build(unit_params)

    if @unit.save
      log_unit_event("created", @unit)
      flash[:notice] = I18n.t("units.messages.created")
      redirect_to @unit
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit = nil

  def update
    # Capture the changes before update
    previous_attributes = @unit.attributes.dup

    if @unit.update(unit_params)
      # Calculate what changed
      changed_data = calculate_changes(previous_attributes, @unit.attributes, unit_params.keys)

      log_unit_event("updated", @unit, nil, changed_data)
      respond_to do |format|
        format.html do
          flash[:notice] = I18n.t("units.messages.updated")
          redirect_to @unit
        end
        format.turbo_stream { render_unit_update_success_stream }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: {status: I18n.t("shared.api.error"), errors: @unit.errors.full_messages}
        end
        format.turbo_stream { render_unit_update_error_stream }
      end
    end
  end

  def destroy
    # Capture unit details before deletion for the audit log
    unit_details = {
      name: @unit.name,
      serial: @unit.serial,
      owner: @unit.owner,
      manufacturer: @unit.manufacturer
    }

    if @unit.destroy
      # Log the deletion with the unit details in metadata
      Event.log(
        user: current_user,
        action: "deleted",
        resource: @unit,
        details: nil,
        metadata: unit_details
      )
      flash[:notice] = I18n.t("units.messages.deleted")
      redirect_to units_path
    else
      @unit.errors.full_messages.first || I18n.t("units.messages.delete_failed") => error_message
      flash[:alert] = error_message
      redirect_to @unit
    end
  end

  def log
    @events = Event.for_resource(@unit).recent.includes(:user)
    @title = I18n.t("units.titles.log", unit: @unit.name)
  end

  def new_from_inspection
    @inspection = current_user.inspections.find_by(id: params[:id])

    unless @inspection
      flash[:alert] = I18n.t("units.errors.inspection_not_found")
      redirect_to root_path and return
    end

    if @inspection.unit
      flash[:alert] = I18n.t("units.errors.inspection_has_unit")
      redirect_to inspection_path(@inspection) and return
    end

    @unit = Unit.new(user: current_user)
  end

  def create_from_inspection
    service = UnitCreationFromInspectionService.new(
      user: current_user,
      inspection_id: params[:id],
      unit_params: unit_params
    )

    if service.create
      log_unit_event("created", service.unit)
      flash[:notice] = I18n.t("units.messages.created_from_inspection")
      redirect_to inspection_path(service.inspection)
    elsif service.error_message
      flash[:alert] = service.error_message
      redirect_path = service.inspection ? inspection_path(service.inspection) : root_path
      redirect_to redirect_path
    else
      @unit = service.unit
      @inspection = service.inspection
      render :new_from_inspection, status: :unprocessable_entity
    end
  end

  private

  def log_unit_event(action, unit, details = nil, changed_data = nil)
    return unless current_user

    if unit
      Event.log(
        user: current_user,
        action: action,
        resource: unit,
        details: details,
        changed_data: changed_data
      )
    else
      # For events without a specific unit (like CSV export)
      Event.log_system_event(
        user: current_user,
        action: action,
        details: details,
        metadata: {resource_type: "Unit"}
      )
    end
  rescue => e
    Rails.logger.error "Failed to log unit event: #{e.message}"
  end

  def calculate_changes(previous_attributes, current_attributes, changed_keys)
    changes = {}

    changed_keys.map(&:to_s).each do |key|
      previous_value = previous_attributes[key]
      current_value = current_attributes[key]

      if previous_value != current_value
        changes[key] = {
          "from" => previous_value,
          "to" => current_value
        }
      end
    end

    changes.presence
  end

  def unit_params
    params.require(:unit).permit(*%i[
      description
      manufacture_date
      manufacturer
      model
      name
      owner
      photo
      serial
    ])
  end

  def no_index = response.set_header("X-Robots-Tag", "noindex,nofollow")

  def set_unit
    @unit = Unit.includes(photo_attachment: :blob)
      .find_by(id: params[:id].upcase)

    unless @unit
      # Always return 404 for non-existent resources regardless of login status
      head :not_found
    end
  end

  def check_unit_owner
    head :not_found unless current_user && @unit.user_id == current_user.id
  end

  def check_log_access
    # Only admins and unit owners can view logs
    # Return 404 for everyone else
    is_owner = current_user && @unit.user_id == current_user.id
    is_admin = current_user&.admin?

    head :not_found unless is_owner || is_admin
  end

  def send_unit_pdf
    # Unit already has photo loaded from set_unit
    pdf_data = PdfGeneratorService.generate_unit_report(
      @unit,
      debug_enabled: admin_debug_enabled?,
      debug_queries: debug_sql_queries
    )

    send_data pdf_data.render,
      filename: "#{@unit.serial}.pdf",
      type: "application/pdf",
      disposition: "inline"
  end

  def send_unit_qr_code
    qr_code_png = QrCodeService.generate_qr_code(@unit)

    send_data qr_code_png,
      filename: "#{@unit.serial}_QR.png",
      type: "image/png",
      disposition: "inline"
  end

  # PublicViewable implementation
  def check_resource_owner
    check_unit_owner
  end

  def owns_resource?
    @unit && current_user && @unit.user_id == current_user.id
  end

  def pdf_filename
    "#{@unit.serial}.pdf"
  end

  def resource_pdf_url
    unit_path(@unit, format: :pdf)
  end

  def filtered_units_query
    units = current_user.units.includes(photo_attachment: :blob)
    units = units.search(params[:query])
    units = units.overdue if params[:status] == "overdue"
    units = units.by_manufacturer(params[:manufacturer])
    units = units.by_owner(params[:owner])
    units.order(created_at: :desc)
  end

  def build_index_title
    title_parts = [I18n.t("units.titles.index")]
    title_parts << I18n.t("units.status.overdue") if params[:status] == "overdue"
    title_parts << params[:manufacturer] if params[:manufacturer].present?
    title_parts << params[:owner] if params[:owner].present?
    title_parts.join(" - ")
  end

  def handle_inactive_user_redirect
    redirect_to units_path
  end
end
