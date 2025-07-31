



@tool
class_name MCPBaseCommandProcessor
extends Node

# Signal emitted when a command has completed processing
signal command_completed(client_id, command_type, result, command_id)

# Reference to the server - passed by the command handler
var _websocket_server = null

# Command result to be set by child classes
var command_result = null

# Must be implemented by subclasses
func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	# Reset command result
	command_result = null
	
	# Call child class implementation
	var handled = _handle_command(command_type, params)
	
	# Send response based on command_result
	if handled and command_result != null:
		if command_result.has("error"):
			_send_error(client_id, command_result["error"], command_id)
		else:
			_send_success(client_id, command_result, command_id)
	
	return handled

# To be implemented by subclasses instead of process_command
func _handle_command(command_type: String, params: Dictionary) -> bool:
	push_error("BaseCommandProcessor._handle_command not implemented")
	return false

# Helper functions common to all command processors
func _send_success(client_id: int, result: Dictionary, command_id: String) -> void:
	var response = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	# Emit the signal for local processing (useful for testing)
	command_completed.emit(client_id, "success", result, command_id)
	
	# Send to websocket if available
	if _websocket_server:
		_websocket_server.send_response(client_id, response)

func _send_error(client_id: int, message: String, command_id: String) -> void:
	var response = {
		"status": "error",
		"message": message
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	# Emit the signal for local processing (useful for testing)
	var error_result = {"error": message}
	command_completed.emit(client_id, "error", error_result, command_id)
	
	# Send to websocket if available
	if _websocket_server:
		_websocket_server.send_response(client_id, response)
	print("Error: %s" % message)

# We try to match the behaviour of get_node here which accomodates a magical
# /root. As a nicety, support relative pathing from /root.
func _get_editor_node(path: String) -> Node:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		print("No edited scene found")
		command_result = {"error": "No scene is currently being edited"}
		return null

	# Check special paths.
	if path in ["/root", "/root/", "", "/root/" + scene_root.name]:
		return scene_root

	if not path.begins_with('/'):
		# This is a relative path.
		if not path.begins_with(scene_root.name):
			# Don't search outside of scene.
			command_result = {"error": "Node not found: %s" % path}
			return null
		var node = scene_root.get_parent().get_node_or_null(path)
		if not node:
			command_result = {"error": "Node not found: %s" % path}
		return node

	if not path.begins_with('/root/' + scene_root.name):
		# Absolute paths _must_ start with /root/SceneRoot
		command_result = {"error": "Node not found: %s" % path}
		return null

	# Remove "/root/SceneRoot/"
	var len = 6 + scene_root.name.length() + 1
	return scene_root.get_node_or_null(path.substr(len))


# Helper function to mark a scene as modified
func _mark_scene_modified() -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	if edited_scene_root:
		# This internally marks the scene as modified in the editor
		EditorInterface.mark_scene_as_unsaved()


