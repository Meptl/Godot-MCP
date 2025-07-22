@tool
class_name MCPNodeCommands
extends MCPBaseCommandProcessor


# Common validation and setup helpers
func _validate_and_get_edited_scene():
	var edited_scene_root = EditorInterface.get_edited_scene_root()

	if not edited_scene_root:
		command_result = {"error": "No scene is currently being edited"}
		return null

	return edited_scene_root


func _validate_and_get_node(node_path: String):
	if node_path.is_empty():
		command_result = {"error": "Node path cannot be empty"}
		return null

	var node = _get_editor_node(node_path)
	if not node:
		command_result = {"error": "Node not found: %s" % node_path}
		return null

	return node


func _validate_property_exists(node: Node, property_name: String) -> bool:
	if not property_name in node:
		command_result = {"error": "Property %s does not exist on node" % property_name}
		return false
	return true


func _handle_command(command_type: String, params: Dictionary) -> bool:
	match command_type:
		"create_node":
			_create_node(params)
			return true
		"delete_node":
			_delete_node(params)
			return true
		"update_node_property":
			_update_node_property(params)
			return true
		"get_node_properties":
			_get_node_properties(params)
			return true
		"update_node_properties":
			_update_node_properties(params)
			return true
		"attach_script":
			_attach_script(params)
			return true
		"reparent_node":
			_reparent_node(params)
			return true
	return false  # Command not handled


func _create_node(params: Dictionary) -> void:
	var parent_path = params.get("parent_path", "/root")
	var node_type = params.get("node_type", "Node")
	var node_name = params.get("node_name", "NewNode")

	# Validation
	if not ClassDB.class_exists(node_type):
		command_result = {"error": "Invalid node type: %s" % node_type}
		return

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return

	# Get the parent node
	var parent = _get_editor_node(parent_path)
	if not parent:
		command_result = {"error": "Parent node not found: %s" % parent_path}
		return

	# Create the node
	var node
	if ClassDB.can_instantiate(node_type):
		node = ClassDB.instantiate(node_type)
	else:
		command_result = {"error": "Cannot instantiate node of type: %s" % node_type}
		return

	if not node:
		command_result = {"error": "Failed to create node of type: %s" % node_type}
		return

	# Set the node name
	node.name = node_name

	parent.add_child(node)
	node.owner = edited_scene_root
	_mark_scene_modified()

	command_result = {"node_path": parent_path + "/" + node_name}


func _delete_node(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return

	# Get and validate the node
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Cannot delete the root node
	if node == edited_scene_root:
		command_result = {"error": "Cannot delete the root node"}
		return

	# Get parent for operation
	var parent = node.get_parent()
	if not parent:
		command_result = {"error": "Node has no parent: %s" % node_path}
		return

	# Remove the node
	parent.remove_child(node)
	node.queue_free()

	# Mark the scene as modified
	_mark_scene_modified()

	command_result = {"deleted_node_path": node_path}


func _update_node_property(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var property_name = params.get("property", "")
	var property_value = params.get("value")

	# Basic validation
	if property_name.is_empty():
		command_result = {"error": "Property name cannot be empty"}
		return

	if property_value == null:
		command_result = {"error": "Property value cannot be null"}
		return

	# Get and validate the node
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Check if the property exists
	if not _validate_property_exists(node, property_name):
		return

	# Parse property value for Godot types
	var parsed_value = _parse_property_value(property_value)

	node.set(property_name, parsed_value)
	_mark_scene_modified()

	command_result = {
		"node_path": node_path,
		"property": property_name,
		"value": property_value,
		"parsed_value": str(parsed_value)
	}


func _update_node_properties(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var properties = params.get("properties", {})

	# Basic validation
	if properties.is_empty():
		command_result = {"error": "Properties dictionary cannot be empty"}
		return

	# Get and validate the node
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Validate all properties exist before updating any
	for property_name in properties:
		if not _validate_property_exists(node, property_name):
			return

	var updated_properties = []

	for property_name in properties:
		var parsed_value = _parse_property_value(properties[property_name])
		node.set(property_name, parsed_value)
		updated_properties.append(property_name)
	_mark_scene_modified()

	command_result = {
		"node_path": node_path,
		"updated_properties": updated_properties,
		"properties": properties
	}


func _get_node_properties(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")

	# Get and validate the node
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Get all properties
	var properties = {}
	var property_list = node.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if not name.begins_with("_"):  # Skip internal properties
			properties[name] = node.get(name)

	command_result = {"node_path": node_path, "properties": properties}




func _attach_script(params: Dictionary) -> void:
	var script_path = params.get("script_path", "")
	var node_path = params.get("node_path", "")

	# Validation
	if script_path.is_empty():
		command_result = {"error": "Script path cannot be empty"}
		return

	if node_path.is_empty():
		command_result = {"error": "Node path cannot be empty"}
		return

	# Make sure we have an absolute path
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	# Check if script file exists
	if not FileAccess.file_exists(script_path):
		command_result = {"error": "Script file not found: %s" % script_path}
		return

	# Get and validate the node
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Get edited scene for owner setting
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return

	# Load the script
	var script = load(script_path)
	if not script:
		command_result = {"error": "Failed to load script: %s" % script_path}
		return

	node.set_script(script)
	_mark_scene_modified()

	command_result = {"script_path": script_path, "node_path": node_path}




func _reparent_node(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var new_parent_path = params.get("new_parent_path", "")
	var index = params.get("index", -1)

	# Basic validation
	if node_path.is_empty():
		command_result = {"error": "Node path cannot be empty"}
		return

	if new_parent_path.is_empty():
		command_result = {"error": "New parent path cannot be empty"}
		return

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return

	# Get and validate the node to move
	var node = _validate_and_get_node(node_path)
	if not node:
		return

	# Get and validate the new parent
	var new_parent = _validate_and_get_node(new_parent_path)
	if not new_parent:
		return

	# Prevent moving to self or descendants
	if node == new_parent:
		command_result = {"error": "Cannot reparent node to itself"}
		return

	# Check if new_parent is a descendant of node
	var current = new_parent
	while current:
		if current == node:
			command_result = {"error": "Cannot reparent node to its own descendant"}
			return
		current = current.get_parent()

	# Cannot reparent the root node
	if node == edited_scene_root:
		command_result = {"error": "Cannot reparent the root node"}
		return

	# Get the current parent
	var old_parent = node.get_parent()
	if not old_parent:
		command_result = {"error": "Node has no parent: %s" % node_path}
		return

	old_parent.remove_child(node)
	if index >= 0 and index < new_parent.get_child_count():
		new_parent.add_child(node)
		new_parent.move_child(node, index)
	else:
		new_parent.add_child(node)
	# Maintain ownership
	node.owner = edited_scene_root
	_mark_scene_modified()

	command_result = {
		"node_path": node_path,
		"old_parent_path": str(old_parent.get_path()),
		"new_parent_path": new_parent_path,
		"index": index if index >= 0 else new_parent.get_child_count() - 1
	}
