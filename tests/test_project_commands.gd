extends GutTest

var project_commands: MCPProjectCommands

func before_each():
	project_commands = MCPProjectCommands.new()
	InputMap.load_from_project_settings()

func after_each():
	if project_commands:
		project_commands.free()

func test_input_map_list_without_builtins():
	var command_params = {
		"show_builtins": false
	}
	
	project_commands._handle_command("input_map_list", command_params)
	var command_result = project_commands.command_result
	
	# Should not contain ui_left builtin action
	assert_false(command_result.actions.has("ui_left"), "Should not contain ui_left builtin action")
	
	# Should contain test_action
	assert_true(command_result.actions.has("test_action"), "Should contain test_action")
	
	# Verify test_action has the expected key event
	var test_action = command_result.actions["test_action"]
	var first_event = test_action.events[0]
	assert_eq(first_event.type, "InputEventKey", "First event should be InputEventKey")
	assert_eq(first_event.physical_keycode, str(KEY_W), "Should have W key mapped")

func test_input_map_list_with_builtins():
	var command_params = {
		"show_builtins": true
	}
	
	project_commands._handle_command("input_map_list", command_params)
	var command_result = project_commands.command_result
	
	# Should contain ui_left builtin action
	assert_true(command_result.actions.has("ui_left"), "Should contain ui_left builtin action")
	
	# Verify ui_left has the expected key event
	var ui_left_action = command_result.actions["ui_left"]
	var ui_left_event = ui_left_action.events[0]
	assert_eq(ui_left_event.type, "InputEventKey", "ui_left first event should be InputEventKey")
	
	# Should contain test_action
	assert_true(command_result.actions.has("test_action"), "Should contain test_action")
	
	# Verify test_action has the expected key event  
	var test_action = command_result.actions["test_action"]
	var test_event = test_action.events[0]
	assert_eq(test_event.type, "InputEventKey", "test_action first event should be InputEventKey")
	assert_eq(test_event.physical_keycode, str(KEY_W), "test_action should have W key mapped")

func test_input_map_list_default_show_builtins():
	var command_params = {}

	project_commands._handle_command("input_map_list", command_params)
	var command_result = project_commands.command_result

	# Should not contain ui_left by default (builtins disabled)
	assert_false(command_result.actions.has("ui_left"), "Should not contain ui_left builtin action by default")

func test_input_map_add_action():
	var test_action_name = "test_new_action"

	# Remove the action if it exists before testing
	if ProjectSettings.has_setting("input/" + test_action_name):
		ProjectSettings.set_setting("input/" + test_action_name, null)

	# Add the action using the input_map_add_action command
	var add_params = {
		"action_name": test_action_name,
		"deadzone": 0.3
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var add_result = project_commands.command_result

	# Verify the action was added successfully
	assert_true(add_result.has("success"), "Should have success message")

	# Verify the action appears in input_map_list
	var list_params = {"show_builtins": false}
	project_commands._handle_command("input_map_list", list_params)
	var list_result = project_commands.command_result

	assert_true(list_result.actions.has(test_action_name), "Added action should appear in list")

	# Clean up: remove the test action
	ProjectSettings.set_setting("input/" + test_action_name, null)

func test_input_map_add_action_default_deadzone():
	var test_action_name = "test_default_deadzone"

	# Remove the action if it exists before testing
	if ProjectSettings.has_setting("input/" + test_action_name):
		ProjectSettings.set_setting("input/" + test_action_name, null)

	# Add the action without specifying deadzone (should use default 0.2)
	var add_params = {
		"action_name": test_action_name
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var add_result = project_commands.command_result

	# Verify the action was added successfully
	assert_true(add_result.has("success"), "Should have success message")

	# Verify the action appears in input_map_list
	var list_params = {"show_builtins": false}
	project_commands._handle_command("input_map_list", list_params)
	var list_result = project_commands.command_result

	assert_true(list_result.actions.has(test_action_name), "Added action should appear in list")

	# Clean up: remove the test action
	ProjectSettings.set_setting("input/" + test_action_name, null)

func test_input_map_add_action_empty_name():
	# Test with empty action name
	var add_params = {
		"action_name": ""
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var add_result = project_commands.command_result

	# Should return error for empty action name
	assert_true(add_result.has("error"), "Should have error for empty action name")

func test_input_map_add_action_already_exists():
	var test_action_name = "test_existing_action"

	# Remove the action if it exists before testing
	if ProjectSettings.has_setting("input/" + test_action_name):
		ProjectSettings.set_setting("input/" + test_action_name, null)

	# First, add the action using our command (should succeed)
	var add_params = {
		"action_name": test_action_name
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var first_result = project_commands.command_result

	# First call should succeed
	assert_true(first_result.has("success"), "First add should succeed")

	# Try to add the same action again (should fail)
	project_commands._handle_command("input_map_add_action", add_params)
	var second_result = project_commands.command_result

	# Second call should return error for action already exists
	assert_true(second_result.has("error"), "Should have error for action already exists")

	# Clean up: remove the test action
	ProjectSettings.set_setting("input/" + test_action_name, null)

var event_type_params = [
	["key", {"keycode": KEY_SPACE, "mods": "none"}, "Should successfully add key event"],
	["key", {"keycode": KEY_A, "mods": "ctrl+shift"}, "Should successfully add key event with modifiers"],
	["key", {"physical_keycode": KEY_B, "mods": "alt"}, "Should successfully add key event with physical keycode"],
	["mouse", {"button_index": MOUSE_BUTTON_LEFT}, "Should successfully add mouse event"],
	["mouse", {"button_index": MOUSE_BUTTON_RIGHT}, "Should successfully add right mouse event"],
	["joy_button", {"button_index": JOY_BUTTON_A}, "Should successfully add joypad button event"],
	["joy_button", {"button_index": JOY_BUTTON_X}, "Should successfully add joypad X button event"],
	["joy_axis", {"axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}, "Should successfully add joypad axis event"],
	["joy_axis", {"axis": JOY_AXIS_RIGHT_Y, "axis_value": 1.0}, "Should successfully add right stick Y axis event"]
]

func test_input_map_add_event_types(params=use_parameters(event_type_params)):
	var event_type = params[0]
	var input_spec = params[1]
	var expected_message = params[2]

	var event_params = {
		"action_name": "test_action",
		"type": event_type,
		"input_spec": input_spec
	}

	project_commands._handle_command("input_map_add_event", event_params)
	var add_result = project_commands.command_result

	assert_true(add_result.has("success"), expected_message)

var error_case_params = [
	["nonexistent_action", "key", {"keycode": KEY_A}, "Should return error for nonexistent action"],
	["test_action", "invalid_type", {}, "Should return error for invalid event type"],
	["test_action", "key", {"mods": "none"}, "Should return error when no keycode or physical_keycode specified"],
	["test_action", "mouse", {}, "Should return error when button_index missing for mouse"],
	["test_action", "joy_button", {}, "Should return error when button_index missing for joy_button"],
	["test_action", "joy_axis", {}, "Should return error when axis missing for joy_axis"],
	["test_action", "joy_axis", {"axis": JOY_AXIS_LEFT_X}, "Should return error when axis_value missing for joy_axis"],
	["test_action", "joy_axis", {"axis": JOY_AXIS_LEFT_X, "axis_value": 0.5}, "Should return error when axis_value is not 1.0 or -1.0"],
	["test_action", "joy_axis", {"axis": JOY_AXIS_LEFT_X, "axis_value": 0.0}, "Should return error when axis_value is 0.0"],
	["test_action", "key", {"keycode": KEY_A, "mods": "invalid_mod"}, "Should return error for invalid modifier"]
]

func test_input_map_add_event_error_cases(params=use_parameters(error_case_params)):
	var action_name = params[0]
	var event_type = params[1]
	var input_spec = params[2]
	var expected_message = params[3]

	var event_params = {
		"action_name": action_name,
		"type": event_type,
		"input_spec": input_spec
	}

	project_commands._handle_command("input_map_add_event", event_params)
	var add_result = project_commands.command_result

	assert_true(add_result.has("error"), expected_message)

func test_input_map_add_event_verification():
	var action_name = "test_action"

	var event_params = {
		"action_name": action_name,
		"type": "key",
		"input_spec": {
			"keycode": KEY_SPACE,
			"mods": "none"
		}
	}

	project_commands._handle_command("input_map_add_event", event_params)
	var add_result = project_commands.command_result

	assert_true(add_result.has("success"), "Should successfully add key event")

	var list_params = {"show_builtins": false}
	project_commands._handle_command("input_map_list", list_params)
	var list_result = project_commands.command_result

	var test_action = list_result.actions["test_action"]
	var events = test_action.events

	var found_space = false
	for event in events:
		if event.type == "InputEventKey" and event.keycode == str(KEY_SPACE):
			found_space = true
			break

	assert_true(found_space, "Should find the added SPACE key event in action")