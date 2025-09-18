extends GutTest

var project_commands: MCPProjectCommands

func before_each():
	project_commands = MCPProjectCommands.new()

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
	assert_eq(first_event.keycode, str(KEY_W), "Should have W key mapped")

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
	assert_eq(test_event.keycode, str(KEY_W), "test_action should have W key mapped")

func test_input_map_list_default_show_builtins():
	var command_params = {}

	project_commands._handle_command("input_map_list", command_params)
	var command_result = project_commands.command_result

	# Should not contain ui_left by default (builtins disabled)
	assert_false(command_result.actions.has("ui_left"), "Should not contain ui_left builtin action by default")

func test_input_map_add_action():
	var test_action_name = "test_new_action"

	# Remove the action if it exists before testing
	if InputMap.has_action(test_action_name):
		InputMap.erase_action(test_action_name)

	# Add the action using the input_map_add_action command
	var add_params = {
		"action_name": test_action_name,
		"deadzone": 0.3
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var add_result = project_commands.command_result

	# Verify the action was added successfully
	assert_true(add_result.has("success"), "Should have success message")

	# Verify the action appears in list_input_map
	var list_params = {"show_builtins": false}
	project_commands._handle_command("list_input_map", list_params)
	var list_result = project_commands.command_result

	assert_true(list_result.actions.has(test_action_name), "Added action should appear in list")

	# Clean up: remove the test action
	InputMap.erase_action(test_action_name)

func test_input_map_add_action_default_deadzone():
	var test_action_name = "test_default_deadzone"

	# Remove the action if it exists before testing
	if InputMap.has_action(test_action_name):
		InputMap.erase_action(test_action_name)

	# Add the action without specifying deadzone (should use default 0.2)
	var add_params = {
		"action_name": test_action_name
	}

	project_commands._handle_command("input_map_add_action", add_params)
	var add_result = project_commands.command_result

	# Verify the action was added successfully
	assert_true(add_result.has("success"), "Should have success message")

	# Verify the action appears in list_input_map
	var list_params = {"show_builtins": false}
	project_commands._handle_command("list_input_map", list_params)
	var list_result = project_commands.command_result

	assert_true(list_result.actions.has(test_action_name), "Added action should appear in list")

	# Clean up: remove the test action
	InputMap.erase_action(test_action_name)

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
	if InputMap.has_action(test_action_name):
		InputMap.erase_action(test_action_name)

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
	InputMap.erase_action(test_action_name)