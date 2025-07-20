@tool
class_name MCPNodeCommands
extends MCPBaseCommandProcessor


# Common validation and setup helpers
func _validate_and_get_edited_scene(client_id: int, command_id: String):
	var edited_scene_root = EditorInterface.get_edited_scene_root()

	if not edited_scene_root:
		_send_error(client_id, "No scene is currently being edited", command_id)
		return null

	return edited_scene_root


func _validate_and_get_node(node_path: String, client_id: int, command_id: String):
	if node_path.is_empty():
		_send_error(client_id, "Node path cannot be empty", command_id)
		return null

	var node = _get_editor_node(node_path)
	if not node:
		_send_error(client_id, "Node not found: %s" % node_path, command_id)
		return null

	return node


func _validate_property_exists(
	node: Node, property_name: String, client_id: int, command_id: String
) -> bool:
	if not property_name in node:
		_send_error(client_id, "Property %s does not exist on node" % property_name, command_id)
		return false
	return true


func process_command(
	client_id: int, command_type: String, params: Dictionary, command_id: String
) -> bool:
	match command_type:
		"create_node":
			_create_node(client_id, params, command_id)
			return true
		"delete_node":
			_delete_node(client_id, params, command_id)
			return true
		"update_node_property":
			_update_node_property(client_id, params, command_id)
			return true
		"get_node_properties":
			_get_node_properties(client_id, params, command_id)
			return true
		"update_node_properties":
			_update_node_properties(client_id, params, command_id)
			return true
		"attach_script":
			_attach_script(client_id, params, command_id)
			return true
		"reparent_node":
			_reparent_node(client_id, params, command_id)
			return true
	return false  # Command not handled


func _create_node(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")
	var node_type = params.get("node_type", "Node")
	var node_name = params.get("node_name", "NewNode")

	# Validation
	if not ClassDB.class_exists(node_type):
		return _send_error(client_id, "Invalid node type: %s" % node_type, command_id)

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene(client_id, command_id)
	if not edited_scene_root:
		return

	# Get the parent node
	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)

	# Create the node
	var node
	if ClassDB.can_instantiate(node_type):
		node = ClassDB.instantiate(node_type)
	else:
		return _send_error(client_id, "Cannot instantiate node of type: %s" % node_type, command_id)

	if not node:
		return _send_error(client_id, "Failed to create node of type: %s" % node_type, command_id)

	# Set the node name
	node.name = node_name

	# Add the node to the parent
	parent.add_child(node)

	# Set owner for proper serialization
	node.owner = edited_scene_root

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(client_id, {"node_path": parent_path + "/" + node_name}, command_id)


func _delete_node(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene(client_id, command_id)
	if not edited_scene_root:
		return

	# Get and validate the node
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Cannot delete the root node
	if node == edited_scene_root:
		return _send_error(client_id, "Cannot delete the root node", command_id)

	# Get parent for operation
	var parent = node.get_parent()
	if not parent:
		return _send_error(client_id, "Node has no parent: %s" % node_path, command_id)

	# Remove the node
	parent.remove_child(node)
	node.queue_free()

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(client_id, {"deleted_node_path": node_path}, command_id)


func _update_node_property(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")
	var property_name = params.get("property", "")
	var property_value = params.get("value")

	# Basic validation
	if property_name.is_empty():
		return _send_error(client_id, "Property name cannot be empty", command_id)

	if property_value == null:
		return _send_error(client_id, "Property value cannot be null", command_id)

	# Get and validate the node
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Check if the property exists
	if not _validate_property_exists(node, property_name, client_id, command_id):
		return

	# Parse property value for Godot types
	var parsed_value = _parse_property_value(property_value)

	# Get current property value for undo
	var old_value = node.get(property_name)

	if not undo_redo:
		# Fallback method if we can't get undo/redo
		node.set(property_name, parsed_value)
		_mark_scene_modified()
	else:
		undo_redo.create_action("Update Property: " + property_name)
		undo_redo.add_do_property(node, property_name, parsed_value)
		undo_redo.add_undo_property(node, property_name, old_value)
		undo_redo.commit_action()

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(
		client_id,
		{
			"node_path": node_path,
			"property": property_name,
			"value": property_value,
			"parsed_value": str(parsed_value)
		},
		command_id
	)


func _update_node_properties(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")
	var properties = params.get("properties", {})

	# Basic validation
	if properties.is_empty():
		return _send_error(client_id, "Properties dictionary cannot be empty", command_id)

	# Get and validate the node
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Validate all properties exist before updating any
	for property_name in properties:
		if not _validate_property_exists(node, property_name, client_id, command_id):
			return

	var updated_properties = []

	if not undo_redo:
		# Fallback method if we can't get undo/redo
		for property_name in properties:
			var parsed_value = _parse_property_value(properties[property_name])
			node.set(property_name, parsed_value)
			updated_properties.append(property_name)
		_mark_scene_modified()
	else:
		undo_redo.create_action("Update Multiple Properties")

		for property_name in properties:
			var parsed_value = _parse_property_value(properties[property_name])
			var old_value = node.get(property_name)
			undo_redo.add_do_property(node, property_name, parsed_value)
			undo_redo.add_undo_property(node, property_name, old_value)
			updated_properties.append(property_name)

		undo_redo.commit_action()

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(
		client_id,
		{
			"node_path": node_path,
			"updated_properties": updated_properties,
			"properties": properties
		},
		command_id
	)


func _get_node_properties(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")

	# Get and validate the node
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Get all properties
	var properties = {}
	var property_list = node.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if not name.begins_with("_"):  # Skip internal properties
			properties[name] = node.get(name)

	_send_success(client_id, {"node_path": node_path, "properties": properties}, command_id)




func _attach_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path = params.get("script_path", "")
	var node_path = params.get("node_path", "")

	# Validation
	if script_path.is_empty():
		return _send_error(client_id, "Script path cannot be empty", command_id)

	if node_path.is_empty():
		return _send_error(client_id, "Node path cannot be empty", command_id)

	# Make sure we have an absolute path
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	# Check if script file exists
	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "Script file not found: %s" % script_path, command_id)

	# Get and validate the node
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Get edited scene for owner setting
	var edited_scene_root = _validate_and_get_edited_scene(client_id, command_id)
	if not edited_scene_root:
		return

	# Load the script
	var script = load(script_path)
	if not script:
		return _send_error(client_id, "Failed to load script: %s" % script_path, command_id)

	if not undo_redo:
		# Fallback method if we can't get undo/redo
		node.set_script(script)
		_mark_scene_modified()
	else:
		undo_redo.create_action("Attach Script")
		undo_redo.add_do_method(node, "set_script", script)
		undo_redo.add_undo_method(node, "set_script", node.get_script())
		undo_redo.commit_action()

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(client_id, {"script_path": script_path, "node_path": node_path}, command_id)




func _reparent_node(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")
	var new_parent_path = params.get("new_parent_path", "")
	var index = params.get("index", -1)

	# Basic validation
	if node_path.is_empty():
		return _send_error(client_id, "Node path cannot be empty", command_id)

	if new_parent_path.is_empty():
		return _send_error(client_id, "New parent path cannot be empty", command_id)

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene(client_id, command_id)
	if not edited_scene_root:
		return

	# Get and validate the node to move
	var node = _validate_and_get_node(node_path, client_id, command_id)
	if not node:
		return

	# Get and validate the new parent
	var new_parent = _validate_and_get_node(new_parent_path, client_id, command_id)
	if not new_parent:
		return

	# Prevent moving to self or descendants
	if node == new_parent:
		return _send_error(client_id, "Cannot reparent node to itself", command_id)

	# Check if new_parent is a descendant of node
	var current = new_parent
	while current:
		if current == node:
			return _send_error(client_id, "Cannot reparent node to its own descendant", command_id)
		current = current.get_parent()

	# Cannot reparent the root node
	if node == edited_scene_root:
		return _send_error(client_id, "Cannot reparent the root node", command_id)

	# Get the current parent
	var old_parent = node.get_parent()
	if not old_parent:
		return _send_error(client_id, "Node has no parent: %s" % node_path, command_id)

	if not undo_redo:
		# Fallback method if we can't get undo/redo
		old_parent.remove_child(node)
		if index >= 0 and index < new_parent.get_child_count():
			new_parent.add_child(node)
			new_parent.move_child(node, index)
		else:
			new_parent.add_child(node)
		# Maintain ownership
		node.owner = edited_scene_root
		_mark_scene_modified()
	else:
		undo_redo.create_action("Reparent Node")
		undo_redo.add_do_method(old_parent, "remove_child", node)
		if index >= 0 and index < new_parent.get_child_count():
			undo_redo.add_do_method(new_parent, "add_child", node)
			undo_redo.add_do_method(new_parent, "move_child", node, index)
		else:
			undo_redo.add_do_method(new_parent, "add_child", node)
		undo_redo.add_do_property(node, "owner", edited_scene_root)
		
		# Undo operations
		undo_redo.add_undo_method(new_parent, "remove_child", node)
		undo_redo.add_undo_method(old_parent, "add_child", node)
		undo_redo.add_undo_property(node, "owner", node.owner)
		
		undo_redo.commit_action()

	# Mark the scene as modified
	_mark_scene_modified()

	_send_success(
		client_id,
		{
			"node_path": node_path,
			"old_parent_path": str(old_parent.get_path()),
			"new_parent_path": new_parent_path,
			"index": index if index >= 0 else new_parent.get_child_count() - 1
		},
		command_id
	)
