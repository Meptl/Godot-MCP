# CLAUDE.md - Godot MCP Project Guidelines

This project is an MCP server for Godot.
It allows AI assistants to interface with Godot.

## Project Structure

The /server folder contains the node mcp server.

The /addons/godot_mcp contains the Godot plugin that the mcp server interfaces with.
This server opens a websocket that the mcp connects to and allows control of the
Godot instance.

See specific documentation in the /docs folder for more detail.

## Code Style Guidelines

### TypeScript (Server)
- Use camelCase for variables, methods, and function names
- Use PascalCase for classes/interfaces
- Strong typing: avoid `any` type
- Prefer async/await over Promise chains
- Import structure: Node modules first, then local modules

### GDScript (Godot)
- Use snake_case for variables, methods, and function names
- Use PascalCase for classes
- Use type hints where possible: `var player: Player`
- Follow Godot singleton conventions (e.g., `Engine`, `OS`)
- Prefer signals for communication between nodes

### General
- Use descriptive names
- Keep functions small and focused
- Add comments for complex logic
- Error handling: prefer try/catch in TS, use assertions in GDScript
