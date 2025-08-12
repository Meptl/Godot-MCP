import WebSocket from 'ws';

/**
 * Response from Godot server
 */
export interface GodotResponse {
  status: 'success' | 'error';
  result?: any;
  message?: string;
  commandId?: string;
}

/**
 * Command to send to Godot
 */
export interface GodotCommand {
  type: string;
  params: Record<string, any>;
  commandId: string;
}

/**
 * Manages WebSocket connection to the Godot editor
 */
export class GodotConnection {
  private ws: WebSocket | null = null;
  private connected = false;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private commandQueue: Map<string, {
    resolve: (value: any) => void;
    reject: (reason: any) => void;
    timeout: NodeJS.Timeout;
  }> = new Map();
  private commandId = 0;
  private url: string = 'ws://127.0.0.1:9080'
  private command_timeout: number = 10000

  constructor(url: string | undefined) {
    console.error('GodotConnection created with URL:', this.url);
    if (url) {
      this.url = url
    }
  }

  connect(): void {
    if (this.connected) return;

    this.ws = new WebSocket(this.url, { protocol: 'json' });

    this.ws.on('open', () => {
      this.connected = true;
      console.error(`Connected to Godot WebSocket server at ${this.url}.`);
      this.heartbeatInterval = setInterval(() => {
        if (this.ws) {
          this.ws.ping();
        }
      }, 3000);
    });

    this.ws.on('message', (data: Buffer) => {
      try {
        const response: GodotResponse = JSON.parse(data.toString());
        console.error('Received response:', response);

        if ('commandId' in response) {
          const commandId = response.commandId as string;
          const pendingCommand = this.commandQueue.get(commandId);

          if (pendingCommand) {
            clearTimeout(pendingCommand.timeout);
            this.commandQueue.delete(commandId);

            if (response.status === 'success') {
              pendingCommand.resolve(response.result);
            } else {
              pendingCommand.reject(new Error(response.message || 'Unknown error'));
            }
          }
        }
      } catch (error) {
        console.error('Error parsing response:', error);
      }
    });

    this.ws.on('error', (error) => {
      const err = error as Error;
      console.error('WebSocket error:', err);
    });

    this.ws.on('close', () => {
      this.connected = false;
      if (this.heartbeatInterval) {
        clearInterval(this.heartbeatInterval);
        this.heartbeatInterval = null;
      }
      this.ws = null;

      // Reject any pending commands
      this.commandQueue.forEach((command, id) => {
        clearTimeout(command.timeout);
        command.reject(new Error('Connection closed'));
      });
      this.commandQueue.clear();

      setTimeout(() => this.connect(), 2000);
    });
  }

  async sendCommand<T = any>(type: string, params: Record<string, any> = {}): Promise<T> {
    if (!this.ws || !this.connected) {
      throw new Error('Not connected to Godot WebSocket. Please ensure Godot is running and the MCP plugin is enabled.');
    }

    return new Promise<T>((resolve, reject) => {
      const commandId = `cmd_${this.commandId++}`;

      const command: GodotCommand = {
        type,
        params,
        commandId
      };

      // Set timeout for command
      const timeoutId = setTimeout(() => {
        if (this.commandQueue.has(commandId)) {
          this.commandQueue.delete(commandId);
          reject(new Error(`Command timed out: ${type}`));
        }
      }, this.command_timeout);

      // Store the promise resolvers
      this.commandQueue.set(commandId, {
        resolve,
        reject,
        timeout: timeoutId
      });

      // Send the command
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(command));
      } else {
        clearTimeout(timeoutId);
        this.commandQueue.delete(commandId);
        reject(new Error('WebSocket not connected'));
      }
    });
  }

  /**
   * Disconnects from the Godot WebSocket server
   */
  disconnect(): void {
    console.error("Disconnecting from Godot WebSocket server.");
    if (this.ws) {
      // Clear all pending commands
      this.commandQueue.forEach((command, commandId) => {
        clearTimeout(command.timeout);
        command.reject(new Error('Connection closed'));
        this.commandQueue.delete(commandId);
      });

      this.ws.close();
    }
  }
}

// Singleton instance
let connectionInstance: GodotConnection | null = null;

export function getGodotConnection(port: number = 9080): GodotConnection {
  if (!connectionInstance) {
    const url = `ws://127.0.0.1:${port}`;
    connectionInstance = new GodotConnection(url);
  }
  return connectionInstance;
}

