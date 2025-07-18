@tool
extends Control

var websocket_server: MCPWebSocketServer
var status_label: Label
var port_input: SpinBox
var start_button: Button
var stop_button: Button
var connection_count_label: Label
var log_text: TextEdit
var autostart_checkbox: CheckBox


func _ready():
	status_label = $VBoxContainer/StatusContainer/StatusLabel
	port_input = $VBoxContainer/PortContainer/PortSpinBox
	start_button = $VBoxContainer/ButtonsContainer/StartButton
	stop_button = $VBoxContainer/ButtonsContainer/StopButton
	connection_count_label = $VBoxContainer/ConnectionsContainer/CountLabel
	log_text = $VBoxContainer/LogContainer/LogText

	# Try to find autostart checkbox
	autostart_checkbox = get_node_or_null("VBoxContainer/AutostartContainer/AutostartCheckBox")

	start_button.pressed.connect(_on_start_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)
	port_input.value_changed.connect(_on_port_changed)

	# Connect autostart checkbox if it exists
	if autostart_checkbox:
		autostart_checkbox.button_pressed = ProjectSettings.get_setting(
			"mcp/server/autostart_enabled", false
		)
		autostart_checkbox.toggled.connect(_on_autostart_toggled)

	# Initial UI setup
	update_ui()

	# Setup server signals once it's available
	await get_tree().process_frame
	if websocket_server:
		websocket_server.connect("client_connected", Callable(self, "_on_client_connected"))
		websocket_server.connect("client_disconnected", Callable(self, "_on_client_disconnected"))
		websocket_server.connect("command_received", Callable(self, "_on_command_received"))

		port_input.value = websocket_server.get_port()

		# Update UI again after signals are connected in case autostart happened
		update_ui()


func update_ui():
	if not websocket_server:
		status_label.text = "Server: Not initialized"
		start_button.disabled = true
		stop_button.disabled = true
		port_input.editable = true
		connection_count_label.text = "0"
		return

	var is_active = websocket_server.is_server_active()

	status_label.text = "Server: " + ("Running" if is_active else "Stopped")
	start_button.disabled = is_active
	stop_button.disabled = not is_active
	port_input.editable = not is_active

	if is_active:
		connection_count_label.text = str(websocket_server.get_client_count())
	else:
		connection_count_label.text = "0"


func _on_start_button_pressed():
	if websocket_server:
		var result = websocket_server.start_server()
		if result == OK:
			# Update the port input to reflect the actual port used
			port_input.value = websocket_server.get_port()
			_log_message("Server started on port " + str(websocket_server.get_port()))
		else:
			_log_message("Failed to start server: " + str(result))
		update_ui()


func _on_stop_button_pressed():
	if websocket_server:
		websocket_server.stop_server()
		_log_message("Server stopped")
		update_ui()


func _on_port_changed(new_port: float):
	if websocket_server:
		websocket_server.set_port(int(new_port))
		_log_message("Port changed to " + str(int(new_port)))


func _on_autostart_toggled(pressed: bool):
	ProjectSettings.set_setting("mcp/server/autostart_enabled", pressed)
	ProjectSettings.save()
	_log_message("Autostart " + ("enabled" if pressed else "disabled"))


func _on_client_connected(client_id: int):
	_log_message("Client connected: " + str(client_id))
	update_ui()


func _on_client_disconnected(client_id: int):
	_log_message("Client disconnected: " + str(client_id))
	update_ui()


func _on_command_received(client_id: int, command: Dictionary):
	var command_type = command.get("type", "unknown")
	var command_id = command.get("commandId", "no-id")
	_log_message(
		(
			"Received command: "
			+ command_type
			+ " (ID: "
			+ command_id
			+ ") from client "
			+ str(client_id)
		)
	)


func _log_message(message: String):
	var timestamp = Time.get_datetime_string_from_system()
	log_text.text += "[" + timestamp + "] " + message + "\n"
	# Auto-scroll to bottom
	log_text.scroll_vertical = log_text.get_line_count()
