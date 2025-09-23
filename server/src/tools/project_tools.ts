import { z } from 'zod';
import { executeGodotCommand } from '../utils/godot_connection.js';
import { MCPTool } from '../utils/types.js';

interface InputMapListParams {
  show_builtins?: boolean;
}

interface InputMapAddActionParams {
  action_name: string;
  deadzone?: number;
}

interface InputMapAddEventParams {
  action_name: string;
  type: string;
  input_spec: Record<string, any>;
}

interface InputMapDeleteActionParams {
  action_name: string;
}

export const projectTools: MCPTool[] = [
  {
    name: 'input_map_list',
    description: 'List all input actions in the InputMap with optional builtin actions',
    parameters: z.object({
      show_builtins: z.boolean()
        .optional()
        .default(false)
        .describe('Whether to include built-in UI actions (ui_*). Default is false.'),
    }),
    execute: async ({ show_builtins = false }: InputMapListParams): Promise<string> => {
      return executeGodotCommand('input_map_list', { show_builtins });
    },
  },
  {
    name: 'input_map_add_action',
    description: 'Add a new action to the InputMap',
    parameters: z.object({
      action_name: z.string()
        .min(1)
        .describe('The name of the action to add to the InputMap'),
      deadzone: z.number()
        .min(0)
        .max(1)
        .optional()
        .default(0.2)
        .describe('The deadzone value for the action (0.0 to 1.0). Default is 0.2.'),
    }),
    execute: async ({ action_name, deadzone = 0.2 }: InputMapAddActionParams): Promise<string> => {
      return executeGodotCommand('input_map_add_action', { action_name, deadzone });
    },
  },
  {
    name: 'input_map_add_event',
    description: 'Add an input event to an existing action in the InputMap',
    parameters: z.object({
      action_name: z.string()
        .min(1)
        .describe('The name of the action to add the event to'),
      type: z.enum(['key', 'mouse', 'joy_button', 'joy_axis'])
        .describe('The type of input event to add'),
      input_spec: z.record(z.any())
        .describe('JSON object specifying the input event details. For key events: {keycode?: number, physical_keycode?: number, mods?: string}. For mouse events: {button_index: number}. For joy_button events: {button_index: number}. For joy_axis events: {axis: number, axis_value: number} where axis_value must be 1.0 or -1.0'),
    }),
    execute: async ({ action_name, type, input_spec }: InputMapAddEventParams): Promise<string> => {
      return executeGodotCommand('input_map_add_event', { action_name, type, input_spec });
    },
  },
  {
    name: 'input_map_delete_action',
    description: 'Delete an action from the InputMap. Note: Builtin actions (ui_*) cannot be deleted.',
    parameters: z.object({
      action_name: z.string()
        .min(1)
        .describe('The name of the action to delete from the InputMap'),
    }),
    execute: async ({ action_name }: InputMapDeleteActionParams): Promise<string> => {
      return executeGodotCommand('input_map_delete_action', { action_name });
    },
  },
];