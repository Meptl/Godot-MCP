extends GutTest

var scene_commands: MCPSceneCommands

func before_each():
	scene_commands = MCPSceneCommands.new()

func after_each():
	if scene_commands:
		scene_commands.free()

var path_params = [
	["tests/artifacts/test_scene.tscn", "res://tests/artifacts/test_scene.tscn"],
	["res://tests/artifacts/test_scene.tscn", "res://tests/artifacts/test_scene.tscn"], 
	["tests/artifacts/test_scene", "res://tests/artifacts/test_scene.tscn"],
	["res://tests/artifacts/test_scene", "res://tests/artifacts/test_scene.tscn"]
]

func test_create_scene_with_valid_path(params=use_parameters(path_params)):
	var input_path = params[0]
	var expected_path = params[1]
	
	# Clean up any existing test file before running
	if FileAccess.file_exists(expected_path):
		DirAccess.remove_absolute(expected_path)
	
	var command_params = {
		"path": input_path,
		"root_node_type": "Node"
	}
	
	scene_commands._handle_command("create_scene", command_params)
	var command_result = scene_commands.command_result
	assert_false(command_result.has("error"), "Should not have error for path: %s" % input_path)
	assert_eq(command_result.scene_path, expected_path, "Path should normalize to %s for input: %s" % [expected_path, input_path])
	
	# Clean up test file after running
	if FileAccess.file_exists(expected_path):
		DirAccess.remove_absolute(expected_path)
