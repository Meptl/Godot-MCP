import { FastMCP } from 'fastmcp';
import { nodeTools } from './tools/node_tools.js';
import { sceneTools } from './tools/scene_tools.js';
import { editorTools } from './tools/editor_tools.js';
import { getGodotConnection } from './utils/godot_connection.js';
import { createServer } from 'http';

// Import resources
import { 
  sceneListResource, 
  sceneStructureResource 
} from './resources/scene_resources.js';
import { 
  scriptResource, 
  scriptListResource,
  scriptMetadataResource 
} from './resources/script_resources.js';
import { 
  projectStructureResource,
  projectSettingsResource,
  projectResourcesResource 
} from './resources/project_resources.js';
import { 
  editorStateResource,
  selectedNodeResource,
  currentScriptResource 
} from './resources/editor_resources.js';

/**
 * Find an available port starting from the given port
 */
async function findAvailablePort(startPort: number): Promise<number> {
  const isPortAvailable = (port: number): Promise<boolean> => {
    return new Promise((resolve) => {
      const server = createServer();
      server.listen(port, () => {
        server.close(() => resolve(true));
      });
      server.on('error', () => resolve(false));
    });
  };

  let port = startPort;
  while (port <= startPort + 100) { // Try up to 100 ports
    if (await isPortAvailable(port)) {
      return port;
    }
    port++;
  }
  
  throw new Error(`No available ports found in range ${startPort} to ${startPort + 100}`);
}

/**
 * Parse command line arguments
 */
function parseArgs(): { useHttp: boolean; port: number; godotPort: number } {
  const args = process.argv.slice(2);
  const useHttp = args.includes('--http');
  const portIndex = args.indexOf('--port');
  const port = portIndex !== -1 && args[portIndex + 1] ? parseInt(args[portIndex + 1]) : 8080;
  const godotPortIndex = args.indexOf('--godot-port');
  const godotPort = godotPortIndex !== -1 && args[godotPortIndex + 1] ? parseInt(args[godotPortIndex + 1]) : 9080;
  
  return { useHttp, port, godotPort };
}

/**
 * Main entry point for the Godot MCP server
 */
async function main() {
  const { useHttp, port, godotPort } = parseArgs();
  
  console.error(`Starting Godot MCP server in ${useHttp ? 'HTTP' : 'stdio'} mode...`);

  // Create FastMCP instance
  const server = new FastMCP({
    name: 'GodotMCP',
    version: '1.0.0',
  });

  // Register all tools
  [...nodeTools, ...sceneTools, ...editorTools].forEach(tool => {
    server.addTool(tool);
  });

  // Register all resources
  // Static resources
  server.addResource(sceneListResource);
  server.addResource(scriptListResource);
  server.addResource(projectStructureResource);
  server.addResource(projectSettingsResource);
  server.addResource(projectResourcesResource);
  server.addResource(editorStateResource);
  server.addResource(selectedNodeResource);
  server.addResource(currentScriptResource);
  server.addResource(sceneStructureResource);
  server.addResource(scriptResource);
  server.addResource(scriptMetadataResource);

  // Try to connect to Godot and start continuous reconnection
  try {
    const godot = getGodotConnection(godotPort);
    await godot.connect();
    console.error(`Successfully connected to Godot WebSocket server on port ${godotPort}`);
  } catch (error) {
    const err = error as Error;
    console.warn(`Could not connect to Godot on port ${godotPort}: ${err.message}`);
    console.warn('Will continuously retry connection in background');
  }

  // Start the server
  if (useHttp) {
    try {
      const availablePort = await findAvailablePort(port);
      if (availablePort !== port) {
        console.error(`Port ${port} is in use, using port ${availablePort} instead`);
      }
      
      server.start({
        transportType: 'httpStream',
        httpStream: {
          endpoint: '/',
          port: availablePort
        }
      });
      console.error(`Godot MCP server started on HTTP port ${availablePort}`);
      console.error(`MCP endpoint available at: http://localhost:${availablePort}/`);
    } catch (error) {
      console.error('Failed to find available port:', error);
      process.exit(1);
    }
  } else {
    server.start({
      transportType: 'stdio',
    });
    console.error('Godot MCP server started with stdio transport');
  }

  console.error('Ready to process commands from Claude or other AI assistants');
  console.error('TIP: Use the analyze_script command to verify GDScript code edits for syntax errors');

  // Handle cleanup
  const cleanup = () => {
    console.error('Shutting down Godot MCP server...');
    const godot = getGodotConnection(godotPort);
    godot.disconnect();
    process.exit(0);
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);

  // Handle unhandled rejections and errors
  process.on('unhandledRejection', (reason: any, promise) => {
    // Check if this is an MCP timeout error
    const errorStr = reason?.toString() || '';
    const contextError = reason?.context?.error;
    
    if (errorStr.includes('Request timed out') || 
        errorStr.includes('-32001') ||
        contextError?.message?.includes('Request timed out') ||
        contextError?.code === -32001) {
      console.error('MCP client request timed out');
      return;
    }
    
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  });

  process.on('uncaughtException', (error) => {
    if (error.message?.includes('ERR_UNHANDLED_ERROR') && error.message?.includes('Request timed out')) {
      console.error('MCP client request timed out');
      return;
    }
    console.error('Uncaught Exception:', error);
    // For other critical errors, exit
    cleanup();
  });
}

// Start the server
main().catch(error => {
  console.error('Failed to start Godot MCP server:', error);
  process.exit(1);
});
