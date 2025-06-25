# CLAUDE.md - Godot MCP Project Guidelines

This project is an MCP server for Godot.
It allows AI assistants to interface with Godot.

## Build & Run Commands
- **Server Build**: `cd server && npm run build`
- **Server Start**: `cd server && npm run start`
- **Server Dev Mode**: `cd server && npm run dev` (auto-rebuild on changes)
- **Run Godot Project**: Open project.godot in Godot Editor

## Project Structure

The /server folder contains the node mcp server.

The root of the repository contains a Godot project with a plugin that allows it
to start a server. This server performs actions and relays information about
Godot to the node server.

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
