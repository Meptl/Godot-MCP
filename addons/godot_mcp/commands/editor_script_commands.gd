@tool
class_name MCPEditorScriptCommands
extends MCPBaseCommandProcessor

func _handle_command(command_type: String, params: Dictionary) -> bool:
	match command_type:
		"execute_editor_script":
			_execute_editor_script(params)
			return true
		"analyze_script":
			_analyze_script(params)
			return true
	return false  # Command not handled

func _execute_editor_script(params: Dictionary) -> void:
	var code = params.get("code", "")
	
	# Validation
	if code.is_empty():
		command_result = {"error": "Code cannot be empty"}
		return
	
	# Create a temporary script node to execute the code
	var script_node := Node.new()
	script_node.name = "EditorScriptExecutor"
	add_child(script_node)
	
	# Create a temporary script
	var script = GDScript.new()
	
	var output = []
	var error_message = ""
	var execution_result = null
	
	# Replace print() calls with custom_print() in the user code
	var modified_code = _replace_print_calls(code)
	
	# Use consistent tab indentation in the template
	var script_content = """@tool
extends Node

signal execution_completed

# Variable to store the result
var result = null
var _output_array = []
var _error_message = ""
var _parent

# Custom print function that stores output in the array
func custom_print(values):
	# Convert array of values to a single string
	var output_str = ""
	if values is Array:
		for i in range(values.size()):
			if i > 0:
				output_str += " "
			output_str += str(values[i])
	else:
		output_str = str(values)
		
	_output_array.append(output_str)
	print(output_str)  # Still print to the console for debugging

func run():
	print("Executing script... ready func")
	_parent = get_parent()
	var scene = get_tree().edited_scene_root
	
	# Execute the provided code
	var err = _execute_code()
	
	# If there was an error, store it
	if err != OK:
		_error_message = "Failed to execute script with error: " + str(err)
	
	# Signal that execution is complete
	execution_completed.emit()

func _execute_code():
	# USER CODE START
{user_code}
	# USER CODE END
	return OK
"""
	
	# Process the user code to ensure consistent indentation
	# This helps prevent "mixed tabs and spaces" errors
	var processed_lines = []
	var lines = modified_code.split("\n")
	for line in lines:
		# Replace any spaces at the beginning with tabs
		var processed_line = line
		
		# If line starts with spaces, replace with a tab
		var space_count = 0
		for i in range(line.length()):
			if line[i] == " ":
				space_count += 1
			else:
				break
		
		# If we found spaces at the beginning, replace with tabs
		if space_count > 0:
			# Create tabs based on space count (e.g., 4 spaces = 1 tab)
			var tabs = ""
			for _i in range(space_count / 4): # Integer division
				tabs += "\t"
			processed_line = tabs + line.substr(space_count)
			
		processed_lines.append(processed_line)
	
	var indented_code = ""
	for line in processed_lines:
		indented_code += "\t" + line + "\n"
	
	script_content = script_content.replace("{user_code}", indented_code)
	script.source_code = script_content
	
	# Check for script errors during parsing
	var error = script.reload()
	if error != OK:
		remove_child(script_node)
		script_node.queue_free()
		command_result = {"error": "Script parsing error: " + str(error)}
		return
	
	# Assign the script to the node
	script_node.set_script(script)
	
	# Execute script and wait for completion
	script_node.run()
	
	# Collect results
	execution_result = script_node.get("result")
	output = script_node._output_array
	error_message = script_node._error_message
	
	# Clean up
	remove_child(script_node)
	script_node.queue_free()
	
	# Build the response
	var result_data = {
		"success": error_message.is_empty(),
		"output": output
	}

	print("result_data: ", result_data)
	
	if not error_message.is_empty():
		result_data["error"] = error_message
	elif execution_result != null:
		result_data["result"] = execution_result
	
	# Set command result
	command_result = result_data

# Replace print() calls with custom_print() in the user code
func _replace_print_calls(code: String) -> String:
	var regex = RegEx.new()
	# Match print statements with any content inside the parentheses
	regex.compile("print\\s*\\(([^\\)]+)\\)")
	
	var result = regex.search_all(code)
	var modified_code = code
	
	# Process matches in reverse order to avoid issues with changing string length
	for i in range(result.size() - 1, -1, -1):
		var match_obj = result[i]
		var full_match = match_obj.get_string()
		var arg_content = match_obj.get_string(1)
		
		# Create an array with all arguments
		var replacement = "custom_print([" + arg_content + "])"
		
		var start = match_obj.get_start()
		var end = match_obj.get_end()
		
		modified_code = modified_code.substr(0, start) + replacement + modified_code.substr(end)
	
	return modified_code

func _analyze_script(params: Dictionary) -> void:
	var script_path = params.get("script_path", "")
	
	if script_path.is_empty():
		command_result = {"error": "Script path cannot be empty"}
		return
	
	# Will be an array of two strings. stdout and stderr.
	var output = []
	var godot_executable = OS.get_executable_path()
	var script_absolute_path = ProjectSettings.globalize_path(script_path)
	var args = ["--headless", "--check-only", "--script", script_absolute_path]
	
	OS.execute(godot_executable, args, output, true)
	
	# Convert PackedStringArray to regular Array.
	output = output.duplicate()
	var stdout_lines = output[0].split("\n")
	# Remove first two lines from stdout (Godot startup output)
	stdout_lines = stdout_lines.slice(2, stdout_lines.size())

	output[0] = "\n".join(stdout_lines)

	command_result = {
		"success": output[0].is_empty(),
		"output": output,
	}
