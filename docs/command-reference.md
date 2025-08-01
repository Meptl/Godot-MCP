# Godot MCP Command Reference

This document provides a reference for the commands available through the Godot MCP integration.

## Node Tools

### create_node
Create a new node in the Godot scene tree.

**Parameters:**
- `parent_path` - Path to the parent node (e.g., "/root", "/root/MainScene")
- `node_type` - Type of node to create (e.g., "Node2D", "Sprite2D", "Label")
- `node_name` - Name for the new node

**Example:**
```
Create a Button node named "StartButton" under the CanvasLayer.
```

### delete_node
Delete a node from the scene tree.

**Parameters:**
- `node_path` - Path to the node to delete

**Example:**
```
Delete the node at "/root/MainScene/UI/OldButton".
```

### update_node_property
Update a property of a node.

**Parameters:**
- `node_path` - Path to the node to update
- `property` - Name of the property to update
- `value` - New value for the property

**Example:**
```
Update the "text" property of the node at "/root/MainScene/UI/Label" to "Game Over".
```

### get_node_properties
Get all properties of a node.

**Parameters:**
- `node_path` - Path to the node to inspect

**Example:**
```
Show me all the properties of the node at "/root/MainScene/Player".
```

### get_node_property_type
Get the type and value of a specific property of a node. Supports indexed properties for nested objects.

**Parameters:**
- `node_path` - Path to the node to inspect
- `property_name` - Name of the property to get type information for. Supports indexed properties using colon notation (e.g., "mesh:size", "material:albedo_color")

**Returns:**
- `value` - The current value of the property
- `type` - The Godot type name as a string (e.g., "Vector2", "String", "Object")
- `type_id` - The numeric Variant type ID
- `class_name` - For Object types, comma-separated list of valid class names

**Examples:**
```
Get the type of the "position" property for the node at "/root/MainScene/Player".
Get the type of the "mesh:size" nested property for the node at "/root/MainScene/MeshInstance3D".
Get the type of the "material:albedo_color" property for a node with material.
```


## Script Tools

### create_script
Create a new GDScript file.

**Parameters:**
- `script_path` - Path where the script will be saved
- `content` - Content of the script
- `node_path` (optional) - Path to a node to attach the script to

**Example:**
```
Create a script at "res://scripts/player_controller.gd" with a basic movement system.
```

### edit_script
Edit an existing GDScript file.

**Parameters:**
- `script_path` - Path to the script file to edit
- `content` - New content of the script

**Example:**
```
Update the script at "res://scripts/player_controller.gd" to add a jump function.
```


### create_script_template
Generate a GDScript template with common boilerplate.

**Parameters:**
- `class_name` (optional) - Optional class name for the script
- `extends_type` - Base class that this script extends (default: "Node")
- `include_ready` - Whether to include the _ready() function (default: true)
- `include_process` - Whether to include the _process() function (default: false)
- `include_input` - Whether to include the _input() function (default: false)
- `include_physics` - Whether to include the _physics_process() function (default: false)

**Example:**
```
Create a script template for a KinematicBody2D with process and input functions.
```

## Scene Tools

### create_scene
Creates a new empty scene with an optional root node type.

**Parameters:**
- `path` (string): Path where the new scene will be saved (e.g. "res://scenes/new_scene.tscn")
- `root_node_type` (string, optional): Type of root node to create (e.g. "Node2D", "Node3D", "Control"). Defaults to "Node" if not specified

**Returns:**
- `scene_path` (string): Path where the scene was saved
- `root_node_type` (string): The type of the root node that was created

**Example:**
```typescript
// Create a new scene with a Node2D as root
const result = await mcp.execute('create_scene', {
  path: 'res://scenes/game_level.tscn',
  root_node_type: 'Node2D'
});
console.log(`Created scene at ${result.scene_path}`);
```

### save_scene
Save the current scene to disk.

**Parameters:**
- `path` (optional) - Path where the scene will be saved (uses current path if not provided)

**Example:**
```
Save the current scene to "res://scenes/level_1.tscn".
```

### open_scene
Open a scene in the editor.

**Parameters:**
- `path` - Path to the scene file to open

**Example:**
```
Open the scene at "res://scenes/main_menu.tscn".
```

### get_current_scene
Get information about the currently open scene.

**Parameters:** None

**Example:**
```
What scene am I currently editing?
```

### get_project_info
Get information about the current Godot project.

**Parameters:** None

**Example:**
```
Tell me about the current project.
```

## Using Commands with Claude

When working with Claude, you don't need to specify the exact command name or format. Instead, describe what you want to do in natural language, and Claude will use the appropriate command. For example:

```
Claude, can you create a new Label node under the UI node with the text "Score: 0"?
```

Claude will understand this request and use the `create_node` command with the appropriate parameters.