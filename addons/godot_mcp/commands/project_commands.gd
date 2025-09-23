@tool
class_name MCPProjectCommands
extends MCPBaseCommandProcessor

func _handle_command(command_type: String, params: Dictionary = {}) -> bool:
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
		"input_map_list":
			_input_map_list(params)
			return true
		"input_map_add_action":
			_input_map_add_action(params)
			return true
		"input_map_add_event":
			_input_map_add_event(params)
			return true
		"input_map_remove_action":
			_input_map_remove_action(params)
			return true
		"input_map_remove_event":
			_input_map_remove_event(params)
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

func _input_map_list(params: Dictionary) -> void:
	var show_builtins = params.get("show_builtins", false)
	InputMap.load_from_project_settings()
	var actions = InputMap.get_actions()
	var input_map_data = {}

	for action in actions:
		if not show_builtins and (action.begins_with("ui_") or action.begins_with("spatial_editor")):
			continue

		var events = InputMap.action_get_events(action)
		var event_list = []

		for event in events:
			var event_data = {}
			event_data["type"] = event.get_class()

			if event is InputEventKey:
				event_data["keycode"] = str(event.keycode)
				event_data["physical_keycode"] = str(event.physical_keycode)

				var mods = []
				if event.ctrl_pressed:
					mods.append("ctrl")
				if event.shift_pressed:
					mods.append("shift")
				if event.alt_pressed:
					mods.append("alt")
				if event.meta_pressed:
					mods.append("meta")

				event_data["mods"] = "none" if mods.is_empty() else "+".join(mods)

			elif event is InputEventMouseButton:
				event_data["button_index"] = event.button_index
			elif event is InputEventJoypadButton:
				event_data["button_index"] = event.button_index
			elif event is InputEventJoypadMotion:
				event_data["axis"] = event.axis

			event_list.append(event_data)

		input_map_data[action] = {
			"events": event_list,
			"deadzone": InputMap.action_get_deadzone(action)
		}

	command_result = {
		"actions": input_map_data
	}

func _input_map_add_action(params: Dictionary) -> void:
	var action_name = params.get("action_name", "")
	var deadzone = params.get("deadzone", 0.2)
	InputMap.load_from_project_settings()

	if action_name.is_empty():
		command_result = {"error": "Action name is required"}
		return

	if ProjectSettings.has_setting("input/" + action_name):
		command_result = {"error": "Action '%s' already exists" % action_name}
		return

	# Modify ProjectSettings directly instead of InputMap singleton 
	# because InputMap changes don't persist to project settings automatically
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": deadzone, "events": []})
	ProjectSettings.save()
	command_result = {"success": "Action '%s' added with deadzone %.2f" % [action_name, deadzone]}

func _input_map_add_event(params: Dictionary) -> void:
	var action_name = params.get("action_name", "")
	var event_type = params.get("type", "")
	var input_spec = params.get("input_spec", {})
	InputMap.load_from_project_settings()

	if action_name.is_empty():
		command_result = {"error": "Action name is required"}
		return

	if not ProjectSettings.has_setting("input/" + action_name):
		command_result = {"error": "Action '%s' does not exist" % action_name}
		return

	if event_type.is_empty():
		command_result = {"error": "Event type is required"}
		return

	var event: InputEvent

	match event_type:
		"key":
			event = _create_key_event(input_spec)
		"mouse":
			event = _create_mouse_event(input_spec)
		"joy_button":
			event = _create_joy_button_event(input_spec)
		"joy_axis":
			event = _create_joy_axis_event(input_spec)
		_:
			command_result = {"error": "Unsupported event type '%s'. Supported types: key, mouse, joy_button, joy_axis" % event_type}
			return

	if event == null:
		return

	# Modify ProjectSettings directly instead of InputMap singleton 
	# because InputMap changes don't persist to project settings automatically
	var current_setting = ProjectSettings.get_setting("input/" + action_name, {"deadzone": 0.2, "events": []})
	current_setting["events"].append(event)
	ProjectSettings.set_setting("input/" + action_name, current_setting)
	ProjectSettings.save()
	command_result = {"success": "Event added to action '%s'" % action_name}

func _create_key_event(input_spec: Dictionary) -> InputEvent:
	var key_event = InputEventKey.new()

	var keycode = input_spec.get("keycode", 0)
	var physical_keycode = input_spec.get("physical_keycode", 0)
	var mods = input_spec.get("mods", "none")

	if keycode == 0 and physical_keycode == 0:
		command_result = {"error": "Either keycode or physical_keycode must be specified"}
		return null

	if keycode != 0:
		key_event.keycode = keycode
	if physical_keycode != 0:
		key_event.physical_keycode = physical_keycode

	if mods != "none":
		var mod_list = mods.split("+")
		for mod in mod_list:
			match mod:
				"ctrl":
					key_event.ctrl_pressed = true
				"shift":
					key_event.shift_pressed = true
				"alt":
					key_event.alt_pressed = true
				"meta":
					key_event.meta_pressed = true
				_:
					command_result = {"error": "Invalid modifier '%s'. Valid modifiers: ctrl, shift, alt, meta" % mod}
					return null

	return key_event

func _create_mouse_event(input_spec: Dictionary) -> InputEvent:
	var mouse_event = InputEventMouseButton.new()

	var button_index = input_spec.get("button_index", 0)

	if button_index == 0:
		command_result = {"error": "button_index is required for mouse events"}
		return null

	mouse_event.button_index = button_index
	mouse_event.pressed = true

	return mouse_event

func _create_joy_button_event(input_spec: Dictionary) -> InputEvent:
	var joy_event = InputEventJoypadButton.new()

	var button_index = input_spec.get("button_index", -1)

	if button_index == -1:
		command_result = {"error": "button_index is required for joy_button events"}
		return null

	joy_event.button_index = button_index
	joy_event.pressed = true

	return joy_event

func _create_joy_axis_event(input_spec: Dictionary) -> InputEvent:
	var joy_event = InputEventJoypadMotion.new()

	var axis = input_spec.get("axis", -1)
	var axis_value = input_spec.get("axis_value", 0.0)

	if axis == -1:
		command_result = {"error": "axis is required for joy_axis events"}
		return null

	if axis_value == 0.0:
		command_result = {"error": "axis_value is required for joy_axis events"}
		return null

	if axis_value != 1.0 and axis_value != -1.0:
		command_result = {"error": "axis_value must be either 1.0 or -1.0 for joy_axis events"}
		return null

	joy_event.axis = axis
	joy_event.axis_value = axis_value

	return joy_event

func _input_map_remove_action(params: Dictionary) -> void:
	var action_name = params.get("action_name", "")
	InputMap.load_from_project_settings()

	if action_name.is_empty():
		command_result = {"error": "Action name is required"}
		return

	# Check if it's a builtin action (cannot be deleted) first
	if action_name.begins_with("ui_"):
		command_result = {"error": "Cannot delete builtin action '%s'" % action_name}
		return

	if not ProjectSettings.has_setting("input/" + action_name):
		command_result = {"error": "Action '%s' does not exist" % action_name}
		return

	# Delete the action by setting it to null
	ProjectSettings.set_setting("input/" + action_name, null)
	ProjectSettings.save()
	command_result = {"success": "Action '%s' deleted" % action_name}

func _input_map_remove_event(params: Dictionary) -> void:
	var action_name = params.get("action_name", "")
	var event_type = params.get("type", "")
	var input_spec = params.get("input_spec", {})

	if action_name.is_empty():
		command_result = {"error": "Action name is required"}
		return

	if not ProjectSettings.has_setting("input/" + action_name):
		command_result = {"error": "Action '%s' does not exist" % action_name}
		return

	if event_type.is_empty():
		command_result = {"error": "Event type is required"}
		return

	var event_to_remove: InputEvent

	match event_type:
		"key":
			event_to_remove = _create_key_event(input_spec)
		"mouse":
			event_to_remove = _create_mouse_event(input_spec)
		"joy_button":
			event_to_remove = _create_joy_button_event(input_spec)
		"joy_axis":
			event_to_remove = _create_joy_axis_event(input_spec)
		_:
			command_result = {"error": "Unsupported event type '%s'. Supported types: key, mouse, joy_button, joy_axis" % event_type}
			return

	if event_to_remove == null:
		return

	var current_setting = ProjectSettings.get_setting("input/" + action_name, {"deadzone": 0.2, "events": []})
	var events = current_setting["events"]
	var event_found = false

	# Find and remove the matching event
	for i in range(events.size() - 1, -1, -1):
		var existing_event = events[i]
		if _events_match(existing_event, event_to_remove):
			events.remove_at(i)
			event_found = true
			break

	if not event_found:
		command_result = {"error": "Event not found in action '%s'" % action_name}
		return

	ProjectSettings.set_setting("input/" + action_name, current_setting)
	ProjectSettings.save()
	command_result = {"success": "Event removed from action '%s'" % action_name}

func _events_match(event1: InputEvent, event2: InputEvent) -> bool:
	if event1.get_class() != event2.get_class():
		return false

	if event1 is InputEventKey and event2 is InputEventKey:
		return event1.keycode == event2.keycode and \
			   event1.physical_keycode == event2.physical_keycode and \
			   event1.ctrl_pressed == event2.ctrl_pressed and \
			   event1.shift_pressed == event2.shift_pressed and \
			   event1.alt_pressed == event2.alt_pressed and \
			   event1.meta_pressed == event2.meta_pressed
	elif event1 is InputEventMouseButton and event2 is InputEventMouseButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadButton and event2 is InputEventJoypadButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadMotion and event2 is InputEventJoypadMotion:
		return event1.axis == event2.axis and event1.axis_value == event2.axis_value

	return false
