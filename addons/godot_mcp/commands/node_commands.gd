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
		"change_node_type":
			_change_node_type(params)
			return true
		"class_derivatives":
			_class_derivatives(params)
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

	var node = _get_editor_node(node_path)
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

	var node = _get_editor_node(node_path)
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

	var node = _get_editor_node(node_path)
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

	var node = _get_editor_node(node_path)
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

	var node = _get_editor_node(node_path)
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

	var node = _get_editor_node(node_path)
	if not node:
		return

	var new_parent = _get_editor_node(new_parent_path)
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


func _change_node_type(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var new_node_type = params.get("node_type", "")
	
	if node_path.is_empty():
		command_result = {"error": "Node path cannot be empty"}
		return
	
	if new_node_type.is_empty():
		command_result = {"error": "Node type cannot be empty"}
		return
	
	if not ClassDB.class_exists(new_node_type):
		command_result = {"error": "Invalid node type: %s" % new_node_type}
		return
	
	if not ClassDB.can_instantiate(new_node_type):
		command_result = {"error": "Cannot instantiate node of type: %s" % new_node_type}
		return
	
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return
	
	var node = _get_editor_node(node_path)
	if not node:
		return
	
	var is_root = node == edited_scene_root
	var parent = node.get_parent()
	var node_index = node.get_index()
	var node_name = node.name
	var node_owner = node.owner
	
	if not is_root and not parent:
		command_result = {"error": "Node has no parent: %s" % node_path}
		return
	
	var properties = {}
	var property_list = node.get_property_list()
	for prop in property_list:
		var prop_name = prop["name"]
		if not prop_name.begins_with("_") and prop_name != "name":
			properties[prop_name] = node.get(prop_name)
	
	var attached_script = node.get_script()
	var children = []
	for child in node.get_children():
		children.append(child)
		node.remove_child(child)
	
	if not is_root:
		parent.remove_child(node)
	
	node.queue_free()
	
	var new_node = ClassDB.instantiate(new_node_type)
	if not new_node:
		command_result = {"error": "Failed to create node of type: %s" % new_node_type}
		return
	
	new_node.name = node_name
	
	if is_root:
		# Use the correct SceneTree API for root nodes
		get_tree().set_edited_scene_root(new_node)
	else:
		parent.add_child(new_node)
		parent.move_child(new_node, node_index)
		new_node.owner = node_owner
	
	for property_name in properties:
		if property_name in new_node:
			new_node.set(property_name, properties[property_name])
	
	if attached_script:
		new_node.set_script(attached_script)
	
	for child in children:
		new_node.add_child(child)
		if is_root:
			child.owner = new_node
	
	_mark_scene_modified()
	
	command_result = {
		"node_path": str(new_node.get_path()),
		"node_type": new_node_type
	}


func _class_derivatives(params: Dictionary) -> void:
	var base_class = params.get("base_class", "")
	
	if base_class.is_empty():
		command_result = {"error": "Base class cannot be empty"}
		return
	
	if not ClassDB.class_exists(base_class):
		command_result = {"error": "Base class does not exist: %s" % base_class}
		return
	
	# Get all classes that inherit from the base class
	var inheritors = ClassDB.get_inheriters_from_class(base_class)
	
	# Create a list that includes the base class itself and all inheritors
	var derivatives = [base_class]
	derivatives.append_array(inheritors)
	
	command_result = {
		"base_class": base_class,
		"derivatives": derivatives
	}

