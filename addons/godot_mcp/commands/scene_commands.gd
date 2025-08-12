@tool
class_name MCPSceneCommands
extends MCPBaseCommandProcessor

func _handle_command(command_type: String, params: Dictionary) -> bool:
	match command_type:
		"save_scene":
			_save_scene(params)
			return true
		"open_scene":
			_open_scene(params)
			return true
		"get_current_scene":
			_get_current_scene(params)
			return true
		"create_scene":
			_create_scene(params)
			return true
		"get_scene_tree":
			_get_scene_tree(params)
			return true
	return false  # Command not handled

func _save_scene(params: Dictionary) -> void:
	var path = params.get("path", "")
	
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	# If no path provided, use the current scene path
	if path.is_empty() and edited_scene_root:
		path = edited_scene_root.scene_file_path
	
	# Validation
	if path.is_empty():
		command_result = {"error": "Scene path cannot be empty"}
		return
	
	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path
	
	if not path.ends_with(".tscn"):
		path += ".tscn"
	
	# Check if we have an edited scene
	if not edited_scene_root:
		command_result = {"error": "No scene is currently being edited"}
		return
	
	# Save the scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(edited_scene_root)
	if result != OK:
		command_result = {"error": "Failed to pack scene: %d" % result}
		return
	
	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		command_result = {"error": "Failed to save scene: %d" % result}
		return
	
	command_result = {
		"scene_path": path
	}

func _open_scene(params: Dictionary) -> void:
	var path = params.get("path", "")
	
	# Validation
	if path.is_empty():
		command_result = {"error": "Scene path cannot be empty"}
		return
	
	# Make sure we have an absolute path
	if not path.begins_with("res://"):
		path = "res://" + path
	
	# Check if the file exists
	if not FileAccess.file_exists(path):
		command_result = {"error": "Scene file not found: %s" % path}
		return
	
	EditorInterface.open_scene_from_path(path)
	command_result = {
		"scene_path": path
	}

func _get_current_scene(_params: Dictionary) -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	if not edited_scene_root:
		print("No scene is currently being edited")
		# Instead of returning an error, return a valid response with empty/default values
		command_result = {
			"scene_path": "None",
			"root_node_type": "None",
			"root_node_name": "None"
		}
		return
	
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Untitled"
	
	print("Current scene path: ", scene_path)
	print("Root node type: ", edited_scene_root.get_class())
	print("Root node name: ", edited_scene_root.name)
	
	command_result = {
		"scene_path": scene_path,
		"root_node_type": edited_scene_root.get_class(),
		"root_node_name": edited_scene_root.name
	}


func _create_scene(params: Dictionary) -> void:
	var path = params.get("path", "")
	var root_node_type = params.get("root_node_type", "Node")
	
	# Validation
	if path.is_empty():
		command_result = {"error": "Scene path cannot be empty"}
		return
	
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
		command_result = {"error": "Scene file already exists: %s" % path}
		return
	
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
				command_result = {"error": "Invalid root node type: %s" % root_node_type}
				return
	
	# Give the root node a name based on the file name
	var file_name = path.get_file().get_basename()
	root_node.name = file_name
	
	# Create a packed scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root_node)
	if result != OK:
		root_node.free()
		command_result = {"error": "Failed to pack scene: %d" % result}
		return
	
	# Save the packed scene to disk
	result = ResourceSaver.save(packed_scene, path)
	if result != OK:
		root_node.free()
		command_result = {"error": "Failed to save scene: %d" % result}
		return
	
	# Clean up
	root_node.free()
	
	# Try to open the scene in the editor
	EditorInterface.open_scene_from_path(path)
	
	command_result = {
		"scene_path": path,
		"root_node_type": root_node_type
	}

func _get_scene_tree(_params: Dictionary) -> void:
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	
	if not edited_scene_root:
		command_result = {"error": "No scene is currently being edited"}
		return
	
	var scene_path = edited_scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = "Untitled"
	
	var tree_output = _build_tree_output(edited_scene_root, 0)
	
	# Return the structure
	command_result = {
		"scene_path": scene_path,
		"tree": tree_output
	}

func _build_tree_output(node: Node, depth: int) -> String:
	# Note: LLMs were not properly reading whitespace-indented bullet points,
	# so we use multiple dashes to represent the depth instead of proper markdown nesting
	var bullets = ""
	for i in depth + 1:
		bullets += "- "
	
	var line = bullets + node.name + " (" + node.get_class() + ")\n"
	
	# Skip recursing into instanced scenes
	# Instanced scenes have a scene_file_path property that is not empty
	if not node.scene_file_path.is_empty():
		# This is an instanced scene, don't recurse into its children
		return line
	
	for child in node.get_children():
		line += _build_tree_output(child, depth + 1)
	
	return line
