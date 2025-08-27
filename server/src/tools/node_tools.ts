import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

/**
 * Type definitions for node tool parameters
 */
interface CreateNodeParams {
  parent_path: string;
  node_type: string;
  node_name: string;
}

interface DeleteNodeParams {
  node_path: string;
}

interface UpdateNodePropertyParams {
  node_path: string;
  property: string;
  value: any;
}

interface GetNodePropertiesParams {
  node_path: string;
}

interface GetNodePropertyTypeParams {
  node_path: string;
  property_name: string;
}


interface UpdateNodePropertiesParams {
  node_path: string;
  properties: Record<string, any>;
}

interface AttachScriptParams {
  node_path: string;
  script_path: string;
}


interface ReparentNodeParams {
  node_path: string;
  new_parent_path: string;
  index?: number;
}

interface ChangeNodeTypeParams {
  node_path: string;
  node_type: string;
}

interface ClassDerivativesParams {
  base_class: string;
}

interface InitializePropertyParams {
  node_path: string;
  property_path: string;
  class_name?: string;
  resource_path?: string;
}

/**
 * Definition for node tools - operations that manipulate nodes in the scene tree
 */
export const nodeTools: MCPTool[] = [
  {
    name: 'create_node',
    description: 'Create a new node in the Godot scene tree',
    parameters: z.object({
      parent_path: z.string()
        .describe('Path to the parent node where the new node will be created (e.g. "/root", "/root/MainScene")'),
      node_type: z.string()
        .describe('Class type of node to create (e.g. "Node2D", "Sprite2D", "Label") or scene resource path (e.g. "res://scenes/Player.tscn")'),
      node_name: z.string()
        .describe('Name for the new node'),
    }),
    execute: async ({ parent_path, node_type, node_name }: CreateNodeParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('create_node', {
          parent_path,
          node_type,
          node_name,
        });
        
        return `Created ${node_type} node named "${node_name}" at ${result.node_path}`;
      } catch (error) {
        throw new Error(`Failed to create node: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'delete_node',
    description: 'Delete a node from the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to delete (e.g. "/root/MainScene/Player")'),
    }),
    execute: async ({ node_path }: DeleteNodeParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        await godot.sendCommand('delete_node', { node_path });
        return `Deleted node at ${node_path}`;
      } catch (error) {
        throw new Error(`Failed to delete node: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'update_node_property',
    description: 'Update a property of a node in the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to update (e.g. "/root/MainScene/Player")'),
      property: z.string()
        .describe('Name of the property to update (e.g. "position", "text", "modulate"). Supports indexed properties like "mesh:size" for nested object properties'),
      value: z.any()
        .describe('New value for the property. For builtin types, use constructor syntax like "Vector3(1.0, 1.0, 1.0)"'),
    }),
    execute: async ({ node_path, property, value }: UpdateNodePropertyParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('update_node_property', {
          node_path,
          property,
          value,
        });
        
        return `Updated property "${property}" of node at ${node_path} to ${JSON.stringify(value)}`;
      } catch (error) {
        throw new Error(`Failed to update node property: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'update_node_properties',
    description: 'Update multiple properties of a node in the Godot scene tree at once',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to update (e.g. "/root/MainScene/Player")'),
      properties: z.record(z.any())
        .describe('Object containing property names and their new values. Supports indexed properties like "mesh:size" for nested object properties. For builtin types, use constructor syntax like "Vector3(1.0, 1.0, 1.0)"'),
    }),
    execute: async ({ node_path, properties }: UpdateNodePropertiesParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('update_node_properties', {
          node_path,
          properties,
        });
        
        const propertyList = Object.keys(properties).join(', ');
        return `Updated properties [${propertyList}] of node at ${node_path}`;
      } catch (error) {
        throw new Error(`Failed to update node properties: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'get_node_properties',
    description: 'Get all properties of a node in the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to inspect (e.g. "/root/MainScene/Player")'),
    }),
    execute: async ({ node_path }: GetNodePropertiesParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('get_node_properties', { node_path });
        
        const sortedEntries = Object.entries(result.properties).sort(([a], [b]) => a.localeCompare(b));
        
        const formattedProperties = sortedEntries
          .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
          .join('\n');
        
        return `Properties of node at ${node_path}:\n\n${formattedProperties}`;
      } catch (error) {
        throw new Error(`Failed to get node properties: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'get_node_property_type',
    description: 'Get the type and value of a specific property of a node in the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to inspect (e.g. "/root/MainScene/Player")'),
      property_name: z.string()
        .describe('Name of the property to get type information for (e.g. "position", "text", "modulate")'),
    }),
    execute: async ({ node_path, property_name }: GetNodePropertyTypeParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('get_node_property_type', { 
          node_path, 
          property_name 
        });
        
        let output = `Property "${property_name}" of node at ${node_path}:\n`;
        output += `  Type: ${result.type}`;
        if (result.class_name) {
          output += ` (Class: ${result.class_name})`;
        }
        output += `\n  Value: ${JSON.stringify(result.value)}`;
        
        return output;
      } catch (error) {
        throw new Error(`Failed to get node property type: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'attach_script',
    description: 'Attach a script to a node in the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to attach the script to (e.g. "/root/MainScene/Player")'),
      script_path: z.string()
        .describe('Path to the script file to attach (e.g. "res://scripts/player.gd")'),
    }),
    execute: async ({ node_path, script_path }: AttachScriptParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('attach_script', {
          node_path,
          script_path,
        });
        
        return `Attached script ${script_path} to node at ${node_path}`;
      } catch (error) {
        throw new Error(`Failed to attach script: ${(error as Error).message}`);
      }
    },
  },


  {
    name: 'reparent_node',
    description: 'Move a node to a new parent in the Godot scene tree',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to move (e.g. "/root/UI/SpawnButton")'),
      new_parent_path: z.string()
        .describe('Path to the new parent node (e.g. "/root/UI/MainVBox/SpawnRow")'),
      index: z.number().optional()
        .describe('Position in the new parent\'s children (optional, defaults to end)'),
    }),
    execute: async ({ node_path, new_parent_path, index }: ReparentNodeParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('reparent_node', {
          node_path,
          new_parent_path,
          index,
        });
        
        return `Moved node from ${node_path} to ${new_parent_path}${index !== undefined ? ` at index ${index}` : ''}`;
      } catch (error) {
        throw new Error(`Failed to reparent node: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'change_node_type',
    description: 'Change the type of an existing node in the Godot scene tree. Note: This does not work for the root node of a scene. For root nodes, recreate the scene with the new node type as a workaround.',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to change (e.g. "/root/MainScene/Player")'),
      node_type: z.string()
        .describe('New node type to change to (e.g. "CharacterBody2D", "RigidBody2D", "StaticBody2D")'),
    }),
    execute: async ({ node_path, node_type }: ChangeNodeTypeParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('change_node_type', {
          node_path,
          node_type,
        });
        
        return `Changed node at ${result.node_path} to ${result.node_type}`;
      } catch (error) {
        throw new Error(`Failed to change node type: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'class_derivatives',
    description: 'Get all classes that derive from a specific base class, including the base class itself',
    parameters: z.object({
      base_class: z.string()
        .describe('The base class name to find derivatives for (e.g. "Shape3D", "PhysicsMaterial")'),
    }),
    execute: async ({ base_class }: ClassDerivativesParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('class_derivatives', {
          base_class,
        });
        
        const derivatives = result.derivatives || [];
        return derivatives.join('\n');
      } catch (error) {
        throw new Error(`Failed to get class derivatives: ${(error as Error).message}`);
      }
    },
  },

  {
    name: 'initialize_property',
    description: 'Initialize a property of a node with an object of the given class or loaded resource',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node (e.g. "/root/MainScene/Player")'),
      property_path: z.string()
        .describe('Path to the property to initialize (e.g. "collision_shape", "texture")'),
      class_name: z.string().optional()
        .describe('Name of the class to instantiate for the property (e.g. "RectangleShape2D", "Texture2D")'),
      resource_path: z.string().optional()
        .describe('Godot resource path to load (e.g. "res://textures/player.png")'),
    }).refine(data => data.class_name || data.resource_path, {
      message: "Either class_name or resource_path must be provided",
    }),
    execute: async ({ node_path, property_path, class_name, resource_path }: InitializePropertyParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand<CommandResult>('initialize_property', {
          node_path,
          property_path,
          class_name,
          resource_path,
        });
        
        const initType = resource_path ? `loaded resource from ${resource_path}` : `${class_name} instance`;
        return `Initialized property "${property_path}" of node at ${node_path} with ${initType}`;
      } catch (error) {
        throw new Error(`Failed to initialize property: ${(error as Error).message}`);
      }
    },
  },
];
