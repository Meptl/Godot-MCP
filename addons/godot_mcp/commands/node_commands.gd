@tool
class_name MCPNodeCommands
extends MCPBaseCommandProcessor


# Common validation and setup helpers
func _validate_and_get_plugin(client_id: int, command_id: String):
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		_send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
		return null
	return plugin


func _validate_and_get_edited_scene(client_id: int, command_id: String):
	var plugin = _validate_and_get_plugin(client_id, command_id)
	if not plugin:
		return null

	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()

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
		"list_nodes":
			_list_nodes(client_id, params, command_id)
			return true
		"update_node_properties":
			_update_node_properties(client_id, params, command_id)
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

	# Get undo/redo system
	var undo_redo = _get_undo_redo()
	if not undo_redo:
		# Fallback method if we can't get undo/redo
		node.set(property_name, parsed_value)
		_mark_scene_modified()
	else:
		# Use undo/redo for proper editor integration
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

	# Get undo/redo system
	var undo_redo = _get_undo_redo()
	var updated_properties = []

	if not undo_redo:
		# Fallback method if we can't get undo/redo
		for property_name in properties:
			var parsed_value = _parse_property_value(properties[property_name])
			node.set(property_name, parsed_value)
			updated_properties.append(property_name)
		_mark_scene_modified()
	else:
		# Use undo/redo for proper editor integration
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


func _list_nodes(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path = params.get("parent_path", "/root")

	# Get the parent node
	var parent = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)

	# Get children
	var children = []
	for child in parent.get_children():
		children.append(
			{
				"name": child.name,
				"type": child.get_class(),
				"path": str(child.get_path()).replace(str(parent.get_path()), parent_path)
			}
		)

	_send_success(client_id, {"parent_path": parent_path, "children": children}, command_id)
