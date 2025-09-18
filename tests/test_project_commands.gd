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