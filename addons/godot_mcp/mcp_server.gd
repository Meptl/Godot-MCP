@tool
extends EditorPlugin

const AUTOSTART_SETTING = "mcp/server/autostart_enabled"

var websocket_server: MCPWebSocketServer
var command_handler = null  # Command handler reference
var panel = null  # Control panel reference

signal client_connected(id)
signal client_disconnected(id)
signal command_received(client_id, command)



func _enter_tree():

	print("\n=== MCP SERVER STARTING ===")

	# Initialize the websocket server
	websocket_server = load("res://addons/godot_mcp/websocket_server.gd").new()
	websocket_server.name = "WebSocketServer"
	add_child(websocket_server)

	# Wait for the websocket server to be ready
	await websocket_server.ready

	# Initialize the command handler
	print("Creating command handler...")
	var handler_script = load("res://addons/godot_mcp/command_handler.gd")
	if handler_script:
		command_handler = Node.new()
		command_handler.set_script(handler_script)
		command_handler.name = "CommandHandler"
		websocket_server.add_child(command_handler)


		# Connect signals
		print("Connecting command handler signals...")
		websocket_server.connect("command_received", Callable(command_handler, "_handle_command"))
	else:
		printerr("Failed to load command handler script!")

	# Initialize the control panel
	panel = load("res://addons/godot_mcp/ui/mcp_panel.tscn").instantiate()
	panel.websocket_server = websocket_server
	add_control_to_bottom_panel(panel, "MCP Server")

	# Check for autostart
	if ProjectSettings.get_setting(AUTOSTART_SETTING, false):
		# Add a small delay to ensure everything is initialized
		await get_tree().create_timer(0.1).timeout

		var result = websocket_server.start_server()
		if result == OK:
			print("MCP Server autostarted successfully on port %d" % websocket_server.get_port())
			# Update the panel UI to reflect the server state and actual port used
			if panel and panel.has_method("update_ui"):
				# Update the port input to reflect the actual port used
				if panel.port_input:
					panel.port_input.value = websocket_server.get_port()
				panel.update_ui()
		else:
			printerr("Failed to autostart MCP Server: %d" % result)

	print("MCP Server plugin initialized")


func _exit_tree():

	# Clean up the panel
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null

	# Clean up the websocket server and command handler
	if websocket_server:
		websocket_server.stop_server()
		websocket_server.queue_free()
		websocket_server = null

	print("=== MCP SERVER SHUTDOWN ===")



