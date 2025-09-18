import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface InputMapListParams {
  show_builtins?: boolean;
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
];