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
		"get_node_property_type":
			_get_node_property_type(params)
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
		"initialize_property":
			_initialize_property(params)
			return true
	return false  # Command not handled


func _create_node(params: Dictionary) -> void:
	var parent_path = params.get("parent_path", "/root")
	var node_type = params.get("node_type", "Node")
	var node_name = params.get("node_name", "NewNode")

	# Get edited scene
	var edited_scene_root = _validate_and_get_edited_scene()
	if not edited_scene_root:
		return

	# Get the parent node
	var parent = _get_editor_node(parent_path)
	if not parent:
		command_result = {"error": "Parent node not found: %s" % parent_path}
		return

	var node

	# Check if node_type is a scene resource path
	if node_type.begins_with("res://"):
		# Create from scene file
		var scene_path = node_type
		if not scene_path.ends_with(".tscn"):
			scene_path += ".tscn"

		if not ResourceLoader.exists(scene_path):
			command_result = {"error": "Scene file not found: %s" % scene_path}
			return

		var packed_scene = ResourceLoader.load(scene_path)
		if not packed_scene or not packed_scene is PackedScene:
			command_result = {"error": "Failed to load scene: %s" % scene_path}
			return

		node = packed_scene.instantiate()
		if not node:
			command_result = {"error": "Failed to instantiate scene: %s" % scene_path}
			return
	else:
		# Create from node class type
		if not ClassDB.class_exists(node_type):
			command_result = {"error": "Invalid node type: %s" % node_type}
			return

		if ClassDB.can_instantiate(node_type):
			node = ClassDB.instantiate(node_type)
		else:
			command_result = {"error": "Cannot instantiate node of type: %s" % node_type}
			return

		if not node:
			command_result = {"error": "Failed to create node of type: %s" % node_type}
			return

	# Find a unique name by checking existing children and adding numeric suffix if needed
	var unique_name = node_name
	var suffix = 2
	while parent.has_node(unique_name):
		unique_name = node_name + str(suffix)
		suffix += 1

	# Set the unique node name
	node.name = unique_name

	parent.add_child(node)
	node.owner = edited_scene_root
	_mark_scene_modified()

	command_result = {"node_path": parent_path.rstrip("/") + "/" + unique_name}


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

	# Check if the property exists. Accommodate indexed properties.
	var first_prop = property_name.split(":")[0]
	if not first_prop in node:
		command_result = {"error": "Property %s does not exist on node" % property_name}
		return

	# Get property type information for validation
	var property_parts = property_name.split(":")
	var type_result = _get_property_type_recursive(node, property_parts)

	if type_result.has("error"):
		command_result = {"error": "Failed to get property type: %s" % type_result["error"]}
		return

	# Parse property value for Godot types, with type conversion
	var parsed_value = _parse_property_value(property_value, type_result["type"])

	# Validate that parsed value is compatible with property type
	var validation_result = _validate_property_value(parsed_value, type_result["type"])
	if validation_result.has("error"):
		command_result = {"error": "Invalid value for property %s: %s" % [property_name, validation_result["error"]]}
		return

	node.set_indexed(property_name, parsed_value)
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

	for prop in properties:
		_update_node_property({
			"node_path": node_path,
			"property": prop,
			"value": properties[prop]
		})

		# If any property update failed, return the error
		if command_result.has("error"):
			return

	command_result = {
		"node_path": node_path,
		"properties": properties
	}


func _get_node_properties(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")

	var node = _get_editor_node(node_path)
	if not node:
		return

	var properties = {}
	_collect_properties_recursive(node, "", properties, 0, 3)

	command_result = {"node_path": node_path, "properties": properties}


func _get_node_property_type(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var property_name = params.get("property_name", "")

	if property_name.is_empty():
		command_result = {"error": "Property name cannot be empty"}
		return

	var node = _get_editor_node(node_path)
	if not node:
		return

	# Check if the first property exists
	var first_prop = property_name.split(":")[0]
	if not first_prop in node:
		command_result = {"error": "Property %s does not exist on node" % first_prop}
		return

	# Use recursive helper to get the property type information
	var property_parts = property_name.split(":")
	var type_result = _get_property_type_recursive(node, property_parts)

	if type_result.has("error"):
		command_result = {
			'error': "Failed to get property type for node %s and property %s: %s" % [node_path, property_name, type_result["error"]]
		}
		return

	command_result = {
		"node_path": node_path,
		"property_name": property_name,
		"value": node.get_indexed(property_name),
		"type": type_result["type"],
	}


func _get_property_type_recursive(obj, property_parts: Array) -> Dictionary:
	# Can't add to match case because <Object#null> is different from null.
	if obj == null:
		return {"error": "Cannot get property on null. Remaining property parts: %s" % property_parts}

	match property_parts.size():
		0:
			return {"error": "_get_property_type_recursive called with empty property_parts"}
		1:
			var prop_name = property_parts[0]
			# We stop at 1 because we need the parent node of the path for field information.
			if typeof(obj) == TYPE_OBJECT:
				var prop_list = obj.get_property_list()
				var prop_info = null

				for prop in prop_list:
					if prop["name"] == prop_name:
						prop_info = prop
						break

				if prop_info == null:
					return {"error": "Property %s not found in %s" % [prop_name, obj]}
				if prop_info.type == TYPE_OBJECT:
					return { 'type': prop_info.class_name }
				else:
					return {"type": _type_to_string(prop_info.type) }
			else:
				# I'm assuming builtins only have primitive fields.
				var prop_check = _builtin_has_prop(obj, prop_name)
				if prop_check.has("error"):
					return prop_check

				if not prop_check["result"]:
					return {"error": "Property %s not found in %s" % [prop_name, obj]}

				var prop_val = obj[prop_name]
				return {"type": _type_to_string(typeof(prop_val))}
		_:
			return _get_property_type_recursive(obj[property_parts[0]], property_parts.slice(1))


func _collect_properties_recursive(obj: Object, prefix: String, properties: Dictionary, current_depth: int, max_depth: int) -> void:
	if current_depth >= max_depth or obj == null:
		return

	var property_list = obj.get_property_list()

	for prop in property_list:
		var name = prop["name"]
		if name.begins_with("_"):
			continue

		var full_name = name if prefix.is_empty() else prefix + ":" + name
		var value = obj.get(name)

		if value == null or not (value is Object):
			properties[full_name] = value
		else:
			properties[full_name] = str(value)

			if _should_skip_object_recursion(value):
				continue

			_collect_properties_recursive(value, full_name, properties, current_depth + 1, max_depth)


func _should_skip_object_recursion(obj: Object) -> bool:
	if obj is Node:
		return true
	if obj is Resource and obj.get_path().is_empty():
		return false
	if obj is PackedScene:
		return true
	if obj is Script:
		return true
	if obj is SceneMultiplayer:
		return true

	return false


func _parse_property_value(value, expected_type: String = ""):
	# Only try to parse strings that look like they could be Godot types
	if typeof(value) == TYPE_STRING and (
		value.begins_with("Vector") or
		value.begins_with("Transform") or
		value.begins_with("Rect") or
		value.begins_with("Color") or
		value.begins_with("Quat") or
		value.begins_with("Basis") or
		value.begins_with("Plane") or
		value.begins_with("AABB") or
		value.begins_with("Projection") or
		value.begins_with("Callable") or
		value.begins_with("Signal") or
		value.begins_with("PackedVector") or
		value.begins_with("PackedString") or
		value.begins_with("PackedFloat") or
		value.begins_with("PackedInt") or
		value.begins_with("PackedColor") or
		value.begins_with("PackedByteArray") or
		value.begins_with("Dictionary") or
		value.begins_with("Array")
	):
		var expression = Expression.new()
		var error = expression.parse(value, [])

		if error == OK:
			var result = expression.execute([], null, true)
			if not expression.has_execute_failed():
				print("Successfully parsed %s as %s" % [value, result])
				value = result
			else:
				print("Failed to execute expression for: %s" % value)
		else:
			print("Failed to parse expression: %s (Error: %d)" % [value, error])

	# Handle type conversions based on expected type
	if not expected_type.is_empty():
		if typeof(value) == TYPE_FLOAT and expected_type == "int":
			# Convert float to int if the property expects an integer
			return int(value)
		elif typeof(value) == TYPE_INT and expected_type == "float":
			# Convert int to float if the property expects a float
			return float(value)
		elif typeof(value) == TYPE_STRING and expected_type == "bool":
			# Convert string to bool if the property expects a boolean
			var lower_value = value.to_lower()
			if lower_value == "true" or lower_value == "1":
				return true
			elif lower_value == "false" or lower_value == "0":
				return false

	# Otherwise, return value as is
	return value






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


func _initialize_property(params: Dictionary) -> void:
	var node_path = params.get("node_path", "")
	var property_path = params.get("property_path", "")
	var cls_name = params.get("class_name", "")

	if node_path.is_empty():
		command_result = {"error": "Node path cannot be empty"}
		return

	if property_path.is_empty():
		command_result = {"error": "Property path cannot be empty"}
		return

	if cls_name.is_empty():
		command_result = {"error": "Class name cannot be empty"}
		return

	if not ClassDB.class_exists(cls_name):
		command_result = {"error": "Class does not exist: %s" % cls_name}
		return

	if not ClassDB.can_instantiate(cls_name):
		command_result = {"error": "Cannot instantiate class: %s (builtin types are not supported)" % cls_name}
		return

	var node = _get_editor_node(node_path)
	if not node:
		return

	# Get property type information for validation using recursive helper
	var property_parts = property_path.split(":")
	var type_result = _get_property_type_recursive(node, property_parts)

	if type_result.has("error"):
		command_result = {"error": "Failed to get property type: %s" % type_result["error"]}
		return

	# Get expected class names for the target property (handle comma-separated list)
	var expected_class_names = []
	if type_result["type"] != "Object":
		var class_name_str = str(type_result["type"])
		expected_class_names = class_name_str.split(",")
		for i in range(expected_class_names.size()):
			expected_class_names[i] = expected_class_names[i].strip_edges()

	# Check if any expected class exists (guard for non-object types)
	if expected_class_names.size() > 0:
		var has_valid_class = false
		for expected_class in expected_class_names:
			if ClassDB.class_exists(expected_class):
				has_valid_class = true
				break
		
		if not has_valid_class:
			command_result = {"error": "Property %s is not of object type (type: %s)" % [property_path, type_result["type"]]}
			return

	# Verify that the specified class is valid for this property
	if expected_class_names.size() > 0:
		var is_valid_class = false
		for expected_class in expected_class_names:
			if expected_class == cls_name or ClassDB.is_parent_class(cls_name, expected_class):
				is_valid_class = true
				break

		if not is_valid_class:
			command_result = {"error": "Class %s is not valid for property %s (expected: %s)" % [cls_name, property_path, expected_class_names]}
			return

	# Create an instance of the class
	var instance = ClassDB.instantiate(cls_name)
	if not instance:
		command_result = {"error": "Failed to instantiate class: %s" % cls_name}
		return

	# Set the property to the new instance using indexed access
	node.set_indexed(property_path, instance)
	_mark_scene_modified()

	command_result = {
		"node_path": node_path,
		"property_path": property_path,
		"class_name": cls_name,
		"success": true
	}


func _type_to_string(type_id: int) -> String:
	match type_id:
		TYPE_NIL:
			return "nil"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_RECT2:
			return "Rect2"
		TYPE_RECT2I:
			return "Rect2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_VECTOR4I:
			return "Vector4i"
		TYPE_PLANE:
			return "Plane"
		TYPE_QUATERNION:
			return "Quaternion"
		TYPE_AABB:
			return "AABB"
		TYPE_BASIS:
			return "Basis"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_PROJECTION:
			return "Projection"
		TYPE_COLOR:
			return "Color"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_RID:
			return "RID"
		TYPE_OBJECT:
			return "Object"
		TYPE_CALLABLE:
			return "Callable"
		TYPE_SIGNAL:
			return "Signal"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_ARRAY:
			return "Array"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY:
			return "PackedVector4Array"
		_:
			return "unknown_type_%d" % type_id


func _builtin_has_prop(obj, prop_name: String) -> Dictionary:
	var obj_type = typeof(obj)
	var type_name = _type_to_string(obj_type)

	match obj_type:
		TYPE_VECTOR2:
			return {"result": prop_name in ["x", "y"]}
		TYPE_VECTOR2I:
			return {"result": prop_name in ["x", "y"]}
		TYPE_VECTOR3:
			return {"result": prop_name in ["x", "y", "z"]}
		TYPE_VECTOR3I:
			return {"result": prop_name in ["x", "y", "z"]}
		TYPE_VECTOR4:
			return {"result": prop_name in ["x", "y", "z", "w"]}
		TYPE_VECTOR4I:
			return {"result": prop_name in ["x", "y", "z", "w"]}
		TYPE_RECT2:
			return {"result": prop_name in ["position", "size", "end"]}
		TYPE_RECT2I:
			return {"result": prop_name in ["position", "size", "end"]}
		TYPE_TRANSFORM2D:
			return {"result": prop_name in ["x", "y", "origin"]}
		TYPE_PLANE:
			return {"result": prop_name in ["normal", "d", "x", "y", "z"]}
		TYPE_QUATERNION:
			return {"result": prop_name in ["x", "y", "z", "w"]}
		TYPE_AABB:
			return {"result": prop_name in ["position", "size", "end"]}
		TYPE_BASIS:
			return {"result": prop_name in ["x", "y", "z"]}
		TYPE_TRANSFORM3D:
			return {"result": prop_name in ["basis", "origin"]}
		TYPE_PROJECTION:
			return {"result": prop_name in ["x", "y", "z", "w"]}
		TYPE_COLOR:
			return {"result": prop_name in ["r", "g", "b", "a", "r8", "g8", "b8", "a8", "h", "s", "v"]}
		TYPE_DICTIONARY:
			return {"result": obj.has(prop_name)}
		_:
			# Unknown type or types we don't support
			return {"error": "Type %s does not support property traversal" % type_name}


func _validate_property_value(value, expected_type_name: String) -> Dictionary:
	var actual_type = typeof(value)
	var actual_type_name = _type_to_string(actual_type)

	if actual_type == TYPE_OBJECT:
		actual_type_name = value.get_class()

	if expected_type_name == actual_type_name:
		return {"valid": true}

	if ClassDB.is_parent_class(actual_type_name, expected_type_name):
		return {"valid": true}

	return {"error": "Expected %s but got %s" % [expected_type_name, actual_type_name]}
