import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface ListInputMapParams {
  show_builtins?: boolean;
}

export const projectTools: MCPTool[] = [
  {
    name: 'list_input_map',
    description: 'List all input actions in the InputMap with optional builtin actions',
    parameters: z.object({
      show_builtins: z.boolean()
        .optional()
        .default(false)
        .describe('Whether to include built-in UI actions (ui_*). Default is false.'),
    }),
    execute: async ({ show_builtins = false }: ListInputMapParams): Promise<string> => {
      const godot = getGodotConnection();

      try {
        const result = await godot.sendCommand<CommandResult>('list_input_map', {
          show_builtins,
        });

        return JSON.stringify(result, null, 2);
      } catch (error) {
        throw new Error(`Failed to list input map: ${(error as Error).message}`);
      }
    },
  },
];