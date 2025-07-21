@tool
class_name MCPSceneCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"save_scene":
			_save_scene(client_id, params, command_id)
			return true
		"open_scene":
			_open_scene(client_id, params, command_id)
			return true
		"get_current_scene":
			_get_current_scene(client_id, params, command_id)
			return true
		"create_scene":
			_create_scene(client_id, params, command_id)
			return true
		"get_scene_tree":
			_get_scene_tree(client_id, params, command_id)
			return true
	return false  # Command not handled

func _save_scene(client_id: int, params: Dictionary, command_id: String) -> void:
	var path = params.get("path", "")
	
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	# If no path provided, use the current scene path
	if path.is_empty() and edited_scene_root:
		path = edited_scene_root.scene_file_path
	
	# Validation
	if path.is_empty():
		return _send_error(client_id, "Scene path cannot be empty", command_id)
	
	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path
	
	if not path.ends_with(".tscn"):
		path += ".tscn"
	
	# Check if we have an edited scene
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)
	
	# Save the scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(edited_scene_root)
	if result != OK:
		return _send_error(client_id, "Failed to pack scene: %d" % result, command_id)
	
	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		return _send_error(client_id, "Failed to save scene: %d" % result, command_id)
	
	_send_success(client_id, {
		"scene_path": path
	}, command_id)

func _open_scene(client_id: int, params: Dictionary, command_id: String) -> void:
	var path = params.get("path", "")
	
	# Validation
	if path.is_empty():
		return _send_error(client_id, "Scene path cannot be empty", command_id)
	
	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path
	
	# Check if the file exists
	if not FileAccess.file_exists(path):
		return _send_error(client_id, "Scene file not found: %s" % path, command_id)
	
	EditorInterface.open_scene_from_path(path)
	_send_success(client_id, {
		"scene_path": path
	}, command_id)

func _get_current_scene(client_id: int, _params: Dictionary, command_id: String) -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	if not edited_scene_root:
		print("No scene is currently being edited")
		# Instead of returning an error, return a valid response with empty/default values
		_send_success(client_id, {
			"scene_path": "None",
			"root_node_type": "None",
			"root_node_name": "None"
		}, command_id)
		return
	
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Untitled"
	
	print("Current scene path: ", scene_path)
	print("Root node type: ", edited_scene_root.get_class())
	print("Root node name: ", edited_scene_root.name)
	
	_send_success(client_id, {
		"scene_path": scene_path,
		"root_node_type": edited_scene_root.get_class(),
		"root_node_name": edited_scene_root.name
	}, command_id)


func _create_scene(client_id: int, params: Dictionary, command_id: String) -> void:
	var path = params.get("path", "")
	var root_node_type = params.get("root_node_type", "Node")
	
	# Validation
	if path.is_empty():
		return _send_error(client_id, "Scene path cannot be empty", command_id)
	
	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path
	
	# Ensure path ends with .tscn
	if not path.ends_with(".tscn"):
		path += ".tscn"
	
	# Create directory structure if it doesn't exist
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open("res://")
		if dir:
			dir.make_dir_recursive(dir_path.trim_prefix("res://"))
	
	# Check if file already exists
	if FileAccess.file_exists(path):
		return _send_error(client_id, "Scene file already exists: %s" % path, command_id)
	
	# Create the root node of the specified type
	var root_node = null
	
	match root_node_type:
		"Node":
			root_node = Node.new()
		"Node2D":
			root_node = Node2D.new()
		"Node3D", "Spatial":
			root_node = Node3D.new()
		"Control":
			root_node = Control.new()
		"CanvasLayer":
			root_node = CanvasLayer.new()
		"Panel":
			root_node = Panel.new()
		_:
			# Attempt to create a custom class if built-in type not recognized
			if ClassDB.class_exists(root_node_type):
				root_node = ClassDB.instantiate(root_node_type)
			else:
				return _send_error(client_id, "Invalid root node type: %s" % root_node_type, command_id)
	
	# Give the root node a name based on the file name
	var file_name = path.get_file().get_basename()
	root_node.name = file_name
	
	# Create a packed scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root_node)
	if result != OK:
		root_node.free()
		return _send_error(client_id, "Failed to pack scene: %d" % result, command_id)
	
	# Save the packed scene to disk
	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		root_node.free()
		return _send_error(client_id, "Failed to save scene: %d" % result, command_id)
	
	# Clean up
	root_node.free()
	
	# Try to open the scene in the editor
	EditorInterface.open_scene_from_path(path)
	
	_send_success(client_id, {
		"scene_path": path,
		"root_node_type": root_node_type
	}, command_id)

func _get_scene_tree(client_id: int, _params: Dictionary, command_id: String) -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)
	
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Untitled"
	
	var tree_output = _build_tree_output(edited_scene_root, 0)
	
	# Return the structure
	_send_success(client_id, {
		"scene_path": scene_path,
		"tree": tree_output
	}, command_id)

func _build_tree_output(node: Node, depth: int) -> String:
	# Note: LLMs were not properly reading whitespace-indented bullet points,
	# so we use multiple dashes to represent the depth instead of proper markdown nesting
	var bullets = ""
	for i in depth + 1:
		bullets += "- "
	
	var line = bullets + node.name + " (" + node.get_class() + ")\n"
	
	for child in node.get_children():
		line += _build_tree_output(child, depth + 1)
	
	return line
