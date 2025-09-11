@tool
class_name MCPProjectCommands
extends MCPBaseCommandProcessor

func _handle_command(command_type: String, params: Dictionary) -> bool:
	match command_type:
		"get_project_info":
			_get_project_info(params)
			return true
		"list_project_files":
			_list_project_files(params)
			return true
		"get_project_structure":
			_get_project_structure(params)
			return true
		"get_project_settings":
			_get_project_settings(params)
			return true
		"list_project_resources":
			_list_project_resources(params)
			return true
		"view_input_map":
			_view_input_map(params)
			return true
		"update_input_map":
			_update_input_map(params)
			return true
	return false  # Command not handled

func _get_project_info(_params: Dictionary) -> void:
	var project_name = ProjectSettings.get_setting("application/config/name", "Untitled Project")
	var project_version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	var project_path = ProjectSettings.globalize_path("res://")
	
	# Get Godot version info and structure it as expected by the server
	var version_info = Engine.get_version_info()
	print("Raw Godot version info: ", version_info)
	
	# Create structured version object with the expected properties
	var structured_version = {
		"major": version_info.get("major", 0),
		"minor": version_info.get("minor", 0),
		"patch": version_info.get("patch", 0)
	}
	
	command_result = {
		"project_name": project_name,
		"project_version": project_version,
		"project_path": project_path,
		"godot_version": structured_version,
		"current_scene": get_tree().edited_scene_root.scene_file_path if get_tree().edited_scene_root else ""
	}

func _list_project_files(params: Dictionary) -> void:
	var extensions = params.get("extensions", [])
	var files = []
	
	# Get all files with the specified extensions
	var dir = DirAccess.open("res://")
	if dir:
		_scan_directory(dir, "", extensions, files)
	else:
		command_result = {"error": "Failed to open res:// directory"}
		return
	
	command_result = {
		"files": files
	}

func _scan_directory(dir: DirAccess, path: String, extensions: Array, files: Array) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			var subdir = DirAccess.open("res://" + path + file_name)
			if subdir:
				_scan_directory(subdir, path + file_name + "/", extensions, files)
		else:
			var file_path = path + file_name
			var has_valid_extension = extensions.is_empty()
			
			for ext in extensions:
				if file_name.ends_with(ext):
					has_valid_extension = true
					break
			
			if has_valid_extension:
				files.append("res://" + file_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _get_project_structure(params: Dictionary) -> void:
	var structure = {
		"directories": [],
		"file_counts": {},
		"total_files": 0
	}
	
	var dir = DirAccess.open("res://")
	if dir:
		_analyze_project_structure(dir, "", structure)
	else:
		command_result = {"error": "Failed to open res:// directory"}
		return
	
	command_result = structure

func _analyze_project_structure(dir: DirAccess, path: String, structure: Dictionary) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			var dir_path = path + file_name + "/"
			structure["directories"].append("res://" + dir_path)
			
			var subdir = DirAccess.open("res://" + dir_path)
			if subdir:
				_analyze_project_structure(subdir, dir_path, structure)
		else:
			structure["total_files"] += 1
			
			var extension = file_name.get_extension()
			if extension in structure["file_counts"]:
				structure["file_counts"][extension] += 1
			else:
				structure["file_counts"][extension] = 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _get_project_settings(params: Dictionary) -> void:
	# Get relevant project settings
	var settings = {
		"project_name": ProjectSettings.get_setting("application/config/name", "Untitled Project"),
		"project_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"display": {
			"width": ProjectSettings.get_setting("display/window/size/viewport_width", 1024),
			"height": ProjectSettings.get_setting("display/window/size/viewport_height", 600),
			"mode": ProjectSettings.get_setting("display/window/size/mode", 0),
			"resizable": ProjectSettings.get_setting("display/window/size/resizable", true)
		},
		"physics": {
			"2d": {
				"default_gravity": ProjectSettings.get_setting("physics/2d/default_gravity", 980)
			},
			"3d": {
				"default_gravity": ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
			}
		},
		"rendering": {
			"quality": {
				"msaa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)
			}
		},
		"input_map": {}
	}
	
	# Get input mappings
	var input_map = ProjectSettings.get_setting("input")
	if input_map:
		settings["input_map"] = input_map
	
	command_result = settings

func _list_project_resources(params: Dictionary) -> void:
	var resources = {
		"scenes": [],
		"scripts": [],
		"textures": [],
		"audio": [],
		"models": [],
		"resources": []
	}
	
	var dir = DirAccess.open("res://")
	if dir:
		_scan_resources(dir, "", resources)
	else:
		command_result = {"error": "Failed to open res:// directory"}
		return
	
	command_result = resources

func _scan_resources(dir: DirAccess, path: String, resources: Dictionary) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			var subdir = DirAccess.open("res://" + path + file_name)
			if subdir:
				_scan_resources(subdir, path + file_name + "/", resources)
		else:
			var file_path = "res://" + path + file_name
			
			# Categorize by extension
			if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				resources["scenes"].append(file_path)
			elif file_name.ends_with(".gd") or file_name.ends_with(".cs"):
				resources["scripts"].append(file_path)
			elif file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg"):
				resources["textures"].append(file_path)
			elif file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3"):
				resources["audio"].append(file_path)
			elif file_name.ends_with(".obj") or file_name.ends_with(".glb") or file_name.ends_with(".gltf"):
				resources["models"].append(file_path)
			elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
				resources["resources"].append(file_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _view_input_map(params: Dictionary) -> void:
	var show_builtins = params.get("show_builtins", false)
	var actions = InputMap.get_actions()
	var input_map_data = {}
	
	for action in actions:
		if not show_builtins and action.begins_with("ui_"):
			continue
			
		var events = InputMap.action_get_events(action)
		var event_list = []
		
		for event in events:
			var event_data = {}
			event_data["type"] = event.get_class()
			
			if event is InputEventKey:
				event_data["keycode"] = event.keycode
				event_data["physical_keycode"] = event.physical_keycode
				event_data["key_label"] = event.key_label
				event_data["pressed"] = event.pressed
				event_data["echo"] = event.echo
				if event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed:
					event_data["modifiers"] = {
						"alt": event.alt_pressed,
						"ctrl": event.ctrl_pressed, 
						"shift": event.shift_pressed,
						"meta": event.meta_pressed
					}
				event_data["as_text"] = event.as_text()
			elif event is InputEventMouseButton:
				event_data["button_index"] = event.button_index
				event_data["pressed"] = event.pressed
				event_data["double_click"] = event.double_click
				event_data["as_text"] = event.as_text()
			elif event is InputEventJoypadButton:
				event_data["button_index"] = event.button_index
				event_data["pressed"] = event.pressed
				event_data["as_text"] = event.as_text()
			elif event is InputEventJoypadMotion:
				event_data["axis"] = event.axis
				event_data["axis_value"] = event.axis_value
				event_data["as_text"] = event.as_text()
			else:
				event_data["as_text"] = event.as_text()
			
			event_list.append(event_data)
		
		input_map_data[action] = {
			"events": event_list,
			"deadzone": InputMap.action_get_deadzone(action)
		}
	
	command_result = {
		"actions": input_map_data,
		"total_actions": actions.size(),
		"show_builtins": show_builtins
	}

func _update_input_map(params: Dictionary) -> void:
	var action = params.get("action", "")
	var operation = params.get("operation", "")
	
	if action.is_empty():
		command_result = {"error": "Action name is required"}
		return
	
	match operation:
		"add_action":
			var deadzone = params.get("deadzone", 0.2)
			if InputMap.has_action(action):
				command_result = {"error": "Action '%s' already exists" % action}
				return
			InputMap.add_action(action, deadzone)
			command_result = {"success": "Action '%s' added with deadzone %.2f" % [action, deadzone]}
		
		"remove_action":
			if not InputMap.has_action(action):
				command_result = {"error": "Action '%s' does not exist" % action}
				return
			InputMap.erase_action(action)
			command_result = {"success": "Action '%s' removed" % action}
		
		"add_event":
			if not InputMap.has_action(action):
				command_result = {"error": "Action '%s' does not exist" % action}
				return
			
			var event_type = params.get("event_type", "")
			var event = _create_input_event(event_type, params)
			if event == null:
				return
			
			InputMap.action_add_event(action, event)
			command_result = {"success": "Event added to action '%s'" % action}
		
		"remove_event":
			if not InputMap.has_action(action):
				command_result = {"error": "Action '%s' does not exist" % action}
				return
			
			var event_type = params.get("event_type", "")
			var event = _create_input_event(event_type, params)
			if event == null:
				return
			
			if not InputMap.action_has_event(action, event):
				command_result = {"error": "Event not found in action '%s'" % action}
				return
			
			InputMap.action_erase_event(action, event)
			command_result = {"success": "Event removed from action '%s'" % action}
		
		"clear_events":
			if not InputMap.has_action(action):
				command_result = {"error": "Action '%s' does not exist" % action}
				return
			
			InputMap.action_erase_events(action)
			command_result = {"success": "All events cleared from action '%s'" % action}
		
		"set_deadzone":
			if not InputMap.has_action(action):
				command_result = {"error": "Action '%s' does not exist" % action}
				return
			
			var deadzone = params.get("deadzone", 0.2)
			InputMap.action_set_deadzone(action, deadzone)
			command_result = {"success": "Deadzone for action '%s' set to %.2f" % [action, deadzone]}
		
		_:
			command_result = {"error": "Unknown operation: %s" % operation}

func _create_input_event(event_type: String, params: Dictionary) -> InputEvent:
	match event_type:
		"key":
			var event = InputEventKey.new()
			var keycode = params.get("keycode", 0)
			var physical_keycode = params.get("physical_keycode", 0)
			
			if keycode > 0:
				event.keycode = keycode
			elif physical_keycode > 0:
				event.physical_keycode = physical_keycode
			else:
				command_result = {"error": "Either keycode or physical_keycode is required for key events"}
				return null
			
			event.pressed = params.get("pressed", true)
			event.echo = params.get("echo", false)
			
			var modifiers = params.get("modifiers", {})
			event.alt_pressed = modifiers.get("alt", false)
			event.ctrl_pressed = modifiers.get("ctrl", false)
			event.shift_pressed = modifiers.get("shift", false)
			event.meta_pressed = modifiers.get("meta", false)
			
			return event
		
		"mouse_button":
			var event = InputEventMouseButton.new()
			var button_index = params.get("button_index", 1)
			
			event.button_index = button_index
			event.pressed = params.get("pressed", true)
			event.double_click = params.get("double_click", false)
			
			return event
		
		"joypad_button":
			var event = InputEventJoypadButton.new()
			var button_index = params.get("button_index", 0)
			
			event.button_index = button_index
			event.pressed = params.get("pressed", true)
			
			return event
		
		"joypad_motion":
			var event = InputEventJoypadMotion.new()
			var axis = params.get("axis", 0)
			var axis_value = params.get("axis_value", 1.0)
			
			event.axis = axis
			event.axis_value = axis_value
			
			return event
		
		_:
			command_result = {"error": "Unknown event type: %s" % event_type}
			return null
