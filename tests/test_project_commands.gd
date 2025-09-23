extends GutTest

# Ephemeral action - removed before and after each test
const TEST_ACTION_EPHEMERAL = "test_action_ephemeral"
# Static action - assumed to exist in project settings, with a W binding.
const TEST_ACTION_STATIC = "test_action"

var project_commands: MCPProjectCommands

func before_each():
	project_commands = MCPProjectCommands.new()
	_delete_action(TEST_ACTION_EPHEMERAL)


func after_each():
	_delete_action(TEST_ACTION_EPHEMERAL)
	if project_commands:
		project_commands.free()


func _init_ephemeral_action():
	project_commands._handle_command("input_map_add_action", {"action_name": TEST_ACTION_EPHEMERAL})


func _delete_action(action_name: String):
	if ProjectSettings.has_setting("input/" + action_name):
		ProjectSettings.set_setting("input/" + action_name, null)
		ProjectSettings.save()


func test_input_map_list_without_builtins():
	project_commands._handle_command("input_map_list", {"show_builtins": false})
	var command_result = project_commands.command_result
	assert_false(command_result.actions.has("ui_left"), "Should not contain ui_left builtin action")
	assert_true(command_result.actions.has(TEST_ACTION_STATIC), "Should contain test_action")
	
	# Verify test_action has the expected key event
	var test_action = command_result.actions[TEST_ACTION_STATIC]
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
	assert_true(command_result.actions.has(TEST_ACTION_STATIC), "Should contain test_action")
	
	# Verify test_action has the expected key event  
	var test_action = command_result.actions[TEST_ACTION_STATIC]
	var test_event = test_action.events[0]
	assert_eq(test_event.type, "InputEventKey", "test_action first event should be InputEventKey")
	assert_eq(test_event.physical_keycode, str(KEY_W), "test_action should have W key mapped")


func test_input_map_list_default_show_builtins():
	project_commands._handle_command("input_map_list", {})
	# Should not contain ui_left by default (builtins disabled)
	assert_false(project_commands.command_result.actions.has("ui_left"), "Should not contain ui_left builtin action by default")


func test_input_map_add_action():
	var add_params = {
		"action_name": TEST_ACTION_EPHEMERAL,
		"deadzone": 0.3
	}
	project_commands._handle_command("input_map_add_action", add_params)
	project_commands._handle_command("input_map_list")
	assert_almost_eq(project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].deadzone, 0.3, 0.01)



func test_input_map_add_action_default_deadzone():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_list")
	assert_almost_eq(project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].deadzone, 0.2, 0.01)


func test_input_map_add_action_empty_name():
	project_commands._handle_command("input_map_add_action", {"action_name": ""})
	assert_true(project_commands.command_result.has("error"), "Should have error for empty action name")


func test_input_map_add_action_already_exists():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_add_action", {"action_name": TEST_ACTION_EPHEMERAL})
	assert_true(project_commands.command_result.has("error"), "Should have error for action already exists")


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
	_init_ephemeral_action()
	var event_type = params[0]
	var input_spec = params[1]
	var expected_message = params[2]

	var event_params = {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": event_type,
		"input_spec": input_spec
	}

	project_commands._handle_command("input_map_add_event", event_params)
	var add_result = project_commands.command_result

	assert_true(add_result.has("success"), expected_message)


var error_case_params = [
	["nonexistent_action", "key", {"keycode": KEY_A}, "Should return error for nonexistent action"],
	[TEST_ACTION_EPHEMERAL, "invalid_type", {}, "Should return error for invalid event type"],
	[TEST_ACTION_EPHEMERAL, "key", {"mods": "none"}, "Should return error when no keycode or physical_keycode specified"],
	[TEST_ACTION_EPHEMERAL, "mouse", {}, "Should return error when button_index missing for mouse"],
	[TEST_ACTION_EPHEMERAL, "joy_button", {}, "Should return error when button_index missing for joy_button"],
	[TEST_ACTION_EPHEMERAL, "joy_axis", {}, "Should return error when axis missing for joy_axis"],
	[TEST_ACTION_EPHEMERAL, "joy_axis", {"axis": JOY_AXIS_LEFT_X}, "Should return error when axis_value missing for joy_axis"],
	[TEST_ACTION_EPHEMERAL, "joy_axis", {"axis": JOY_AXIS_LEFT_X, "axis_value": 0.5}, "Should return error when axis_value is not 1.0 or -1.0"],
	[TEST_ACTION_EPHEMERAL, "joy_axis", {"axis": JOY_AXIS_LEFT_X, "axis_value": 0.0}, "Should return error when axis_value is 0.0"],
	[TEST_ACTION_EPHEMERAL, "key", {"keycode": KEY_A, "mods": "invalid_mod"}, "Should return error for invalid modifier"]
]


func test_input_map_add_event_error_cases(params=use_parameters(error_case_params)):
	_init_ephemeral_action()
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


func test_input_map_remove_action():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_list")
	assert_true(project_commands.command_result.actions.has(TEST_ACTION_EPHEMERAL), "Action should exist before removal")

	project_commands._handle_command("input_map_remove_action", {"action_name": TEST_ACTION_EPHEMERAL})
	var remove_result = project_commands.command_result
	assert_true(remove_result.has("success"), "Should successfully remove action")

	project_commands._handle_command("input_map_list")
	assert_false(project_commands.command_result.actions.has(TEST_ACTION_EPHEMERAL), "Action should not exist after removal")


func test_input_map_remove_action_empty_name():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_remove_action", {"action_name": ""})
	assert_true(project_commands.command_result.has("error"), "Should have error for empty action name")


func test_input_map_remove_action_nonexistent():
	project_commands._handle_command("input_map_remove_action", {"action_name": "nonexistent_action"})
	assert_true(project_commands.command_result.has("error"), "Should have error for nonexistent action")


func test_input_map_remove_action_builtins():
	project_commands._handle_command("input_map_remove_action", {"action_name": "ui_left"})
	var result = project_commands.command_result
	assert_true(result.has("error"), "Should have error when trying to remove builtin ui_ action")
	assert_true(result.error.contains("Cannot delete builtin action"), "Error should mention builtin action")


func test_input_map_remove_event():
	_init_ephemeral_action()

	# Add an event first
	var add_params = {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_SPACE, "mods": "none"}
	}
	project_commands._handle_command("input_map_add_event", add_params)
	assert_true(project_commands.command_result.has("success"), "Should successfully add event")

	# Verify the event exists
	project_commands._handle_command("input_map_list")
	var action_events = project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].events
	assert_eq(action_events.size(), 1, "Should have 1 event after adding")

	# Remove the event
	var remove_params = {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_SPACE, "mods": "none"}
	}
	project_commands._handle_command("input_map_remove_event", remove_params)
	var remove_result = project_commands.command_result
	assert_true(remove_result.has("success"), "Should successfully remove event")

	# Verify the event is gone
	project_commands._handle_command("input_map_list")
	var action_events_after = project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].events
	assert_eq(action_events_after.size(), 0, "Should have 0 events after removing")


func test_input_map_remove_event_empty_action_name():
	project_commands._handle_command("input_map_remove_event", {
		"action_name": "",
		"type": "key",
		"input_spec": {"keycode": KEY_A}
	})
	assert_true(project_commands.command_result.has("error"), "Should have error for empty action name")


func test_input_map_remove_event_nonexistent_action():
	project_commands._handle_command("input_map_remove_event", {
		"action_name": "nonexistent_action",
		"type": "key",
		"input_spec": {"keycode": KEY_A}
	})
	assert_true(project_commands.command_result.has("error"), "Should have error for nonexistent action")


func test_input_map_remove_event_empty_type():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_remove_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "",
		"input_spec": {"keycode": KEY_A}
	})
	assert_true(project_commands.command_result.has("error"), "Should have error for empty event type")


func test_input_map_remove_event_invalid_type():
	_init_ephemeral_action()
	project_commands._handle_command("input_map_remove_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "invalid_type",
		"input_spec": {"keycode": KEY_A}
	})
	assert_true(project_commands.command_result.has("error"), "Should have error for invalid event type")


func test_input_map_remove_event_not_found():
	_init_ephemeral_action()

	# Try to remove an event that doesn't exist
	project_commands._handle_command("input_map_remove_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_SPACE, "mods": "none"}
	})
	var result = project_commands.command_result
	assert_true(result.has("error"), "Should have error when event not found")
	assert_true(result.error.contains("Event not found"), "Error should mention event not found")


func test_input_map_remove_event_multiple_events():
	_init_ephemeral_action()

	# Add multiple events
	project_commands._handle_command("input_map_add_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_SPACE, "mods": "none"}
	})
	project_commands._handle_command("input_map_add_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_A, "mods": "ctrl"}
	})

	# Verify we have 2 events
	project_commands._handle_command("input_map_list")
	var action_events = project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].events
	assert_eq(action_events.size(), 2, "Should have 2 events after adding both")

	# Remove one specific event
	project_commands._handle_command("input_map_remove_event", {
		"action_name": TEST_ACTION_EPHEMERAL,
		"type": "key",
		"input_spec": {"keycode": KEY_SPACE, "mods": "none"}
	})
	assert_true(project_commands.command_result.has("success"), "Should successfully remove first event")

	# Verify we have 1 event left
	project_commands._handle_command("input_map_list")
	var action_events_after = project_commands.command_result.actions[TEST_ACTION_EPHEMERAL].events
	assert_eq(action_events_after.size(), 1, "Should have 1 event left after removing one")

	# Verify the remaining event is the correct one (KEY_A with ctrl)
	var remaining_event = action_events_after[0]
	assert_eq(remaining_event.keycode, str(KEY_A), "Remaining event should be KEY_A")
	assert_eq(remaining_event.mods, "ctrl", "Remaining event should have ctrl modifier")
