import { z } from 'zod';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool } from '../utils/types.js';

interface ExecuteEditorScriptParams {
  code: string;
}

export const editorTools: MCPTool[] = [
  {
    name: 'initialize',
    description: 'Initialize the Godot MCP session. If you haven\'t received instructions on how to use Godot-MCP\'s tools in the system prompt, you should always call this tool before starting to work.',
    parameters: z.object({}),
    execute: async (): Promise<string> => {
      const __filename = fileURLToPath(import.meta.url);
      const __dirname = dirname(__filename);
      const initFilePath = join(__dirname, 'initialize.txt');
      
      try {
        return readFileSync(initFilePath, 'utf-8').trim();
      } catch (error) {
        throw new Error(`Failed to read initialization file: ${(error as Error).message}`);
      }
    },
  },
  
  {
    name: 'execute_editor_script',
    description: 'Executes arbitrary GDScript code in the Godot editor',
    parameters: z.object({
      code: z.string()
        .describe('GDScript code to execute in the editor context'),
    }),
    execute: async ({ code }: ExecuteEditorScriptParams): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand('execute_editor_script', { code });
        
        // Format output for display
        let outputText = 'Script executed successfully';
        
        if (result.output && Array.isArray(result.output) && result.output.length > 0) {
          outputText += '\n\nOutput:\n' + result.output.join('\n');
        }
        
        if (result.result) {
          outputText += '\n\nResult:\n' + JSON.stringify(result.result, null, 2);
        }
        
        return outputText;
      } catch (error) {
        throw new Error(`Script execution failed: ${(error as Error).message}`);
      }
    },
  },
  
  {
    name: 'analyze_script',
    description: 'Analyze a GDScript file for syntax errors and potential issues. Returns JSON with "success" (true if no errors) and "output" (array where output[0] is stdout, output[1] is stderr if present). Use this to verify the correctness of GDScript code edits you make.',
    parameters: z.object({
      script_path: z.string()
        .describe('Path to the GDScript file to analyze (e.g. "res://scripts/player.gd")'),
    }),
    execute: async ({ script_path }): Promise<string> => {
      const godot = getGodotConnection();
      
      try {
        const result = await godot.sendCommand('analyze_script', { script_path });
        return JSON.stringify(result, null, 2);
      } catch (error) {
        throw new Error(`Failed to analyze script: ${(error as Error).message}`);
      }
    },
  },
];
