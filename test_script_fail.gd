extends Node

func _ready():
	# This will cause a syntax error - undefined variable
	print(undefined_variable)
	
	# This will cause another error - wrong function name
	invalid_function_call()
	
	# Missing return type annotation will cause warning/error
	func broken_function()
		return "missing colon"