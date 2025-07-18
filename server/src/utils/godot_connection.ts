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
  private reconnecting = false;
  private retryTimer: NodeJS.Timeout | null = null;
  private commandQueue: Map<string, { 
    resolve: (value: any) => void;
    reject: (reason: any) => void;
    timeout: NodeJS.Timeout;
  }> = new Map();
  private commandId = 0;
  private shouldReconnect = true;

  constructor(
    private url: string = 'ws://localhost:9080',
    private timeout: number = 20000,
    private initialRetryDelay: number = 2000,
    private maxRetryDelay: number = 30000
  ) {
    console.error('GodotConnection created with URL:', this.url);
  }
  
  /**
   * Connects to the Godot WebSocket server
   */
  async connect(): Promise<void> {
    if (this.connected) return;
    if (this.reconnecting) return;

    this.reconnecting = true;
    
    const tryConnect = (): Promise<void> => {
      return new Promise<void>((resolve, reject) => {
        console.error(`Connecting to Godot WebSocket server at ${this.url}...`);

        this.ws = new WebSocket(this.url, {
          protocol: 'json',
          handshakeTimeout: 8000,  // Increase handshake timeout
          perMessageDeflate: false // Disable compression for compatibility
        });
        
        this.ws.on('open', () => {
          this.connected = true;
          this.reconnecting = false;
          resolve();
        });
        
        this.ws.on('message', (data: Buffer) => {
          try {
            const response: GodotResponse = JSON.parse(data.toString());
            console.error('Received response:', response);
            
            // Handle command responses
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
          // Don't terminate the connection on error - let the timeout handle it
          // Just log the error and allow retry mechanism to work
        });
        
        this.ws.on('close', () => {
          if (this.connected) {
            console.error('Disconnected from Godot WebSocket server');
            this.connected = false;
          }
        });

        this.ws.on('close', (code: number, reason: string) => {
          console.error(`WebSocket closed (code: ${code}, reason: ${reason || 'No reason provided'})`);
          this.connected = false;
          this.ws = null;

          // Reject pending commands
          this.commandQueue.forEach((command, id) => {
            clearTimeout(command.timeout);
            command.reject(new Error('Connection closed'));
          });
          this.commandQueue.clear();

          // Start continuous reconnection if enabled
          if (this.shouldReconnect && !this.reconnecting) {
            this.scheduleReconnect();
          }
        });

        // Set connection timeout
        const connectionTimeout = setTimeout(() => {
          if (this.ws?.readyState !== WebSocket.OPEN) {
            if (this.ws) {
              this.ws.terminate();
              this.ws = null;
            }
            reject(new Error('Connection timeout'));
          }
        }, this.timeout);
        
        this.ws.on('open', () => {
          clearTimeout(connectionTimeout);
        });
      });
    };

    try {
      await tryConnect();
    } catch (error) {
      this.reconnecting = false;
      
      // Schedule reconnection for continuous retry
      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
      
      throw error;
    }
  }

  private scheduleReconnect(): void {
    if (this.retryTimer) {
      clearTimeout(this.retryTimer);
    }
    
    // Use exponential backoff with jitter, capped at maxRetryDelay
    const delay = Math.min(
      this.initialRetryDelay + Math.random() * 1000,
      this.maxRetryDelay
    );
    
    console.error(`Scheduling reconnection attempt in ${Math.round(delay)}ms...`);
    
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null;
      this.connect().catch(() => {
        // Connection failed, scheduleReconnect will be called again from the close handler
      });
    }, delay);
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
      }, this.timeout);
      
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
    this.shouldReconnect = false;
    
    if (this.retryTimer) {
      clearTimeout(this.retryTimer);
      this.retryTimer = null;
    }
    
    if (this.ws) {
      // Clear all pending commands
      this.commandQueue.forEach((command, commandId) => {
        clearTimeout(command.timeout);
        command.reject(new Error('Connection closed'));
        this.commandQueue.delete(commandId);
      });
      
      this.ws.close();
      this.ws = null;
      this.connected = false;
    }
  }
  
  /**
   * Checks if connected to Godot
   */
  isConnected(): boolean {
    return this.connected;
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

