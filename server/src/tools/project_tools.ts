import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface InputMapListParams {
  show_builtins?: boolean;
}

interface InputMapAddActionParams {
  action_name: string;
  deadzone?: number;
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
      const godot = getGodotConnection();

      try {
        const result = await godot.sendCommand<CommandResult>('input_map_list', {
          show_builtins,
        });

        return JSON.stringify(result, null, 2);
      } catch (error) {
        throw new Error(`Failed to list input map: ${(error as Error).message}`);
      }
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
      const godot = getGodotConnection();

      try {
        const result = await godot.sendCommand<CommandResult>('input_map_add_action', {
          action_name,
          deadzone,
        });

        return JSON.stringify(result, null, 2);
      } catch (error) {
        throw new Error(`Failed to add input map action: ${(error as Error).message}`);
      }
    },
  },
];