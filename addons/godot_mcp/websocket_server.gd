@tool
class_name MCPWebSocketServer
extends Node

signal client_connected(id)
signal client_disconnected(id)
signal command_received(client_id, command)

# Custom implementation of WebSocket server using TCP + WebSocketPeer
var tcp_server = TCPServer.new()
var peers = {}
var pending_peers = []
var _port = 9080
var refuse_new_connections = false
var handshake_timeout = 3000 # ms

class PendingPeer:
	var tcp: StreamPeerTCP
	var connection: StreamPeer
	var ws: WebSocketPeer = null
	var connect_time: int
	
	func _init(p_tcp: StreamPeerTCP):
		tcp = p_tcp
		connection = tcp
		connect_time = Time.get_ticks_msec()


func _ready():
	set_process(false)


func _process(_delta):
	poll()


func is_server_active() -> bool:
	return tcp_server.is_listening()


func set_port(port: int) -> void:
	_port = port


func get_port() -> int:
	return _port


func start_server() -> int:
	if is_server_active():
		return ERR_ALREADY_IN_USE

	# Try to find an available port, starting from the configured port
	var current_port = _port
	var max_attempts = 100
	var attempt = 0
	
	while attempt < max_attempts:
		var err = tcp_server.listen(current_port, "127.0.0.1")
		if err == OK:
			# Update the port to reflect the actual port we're using
			_port = current_port
			set_process(true)
			print("MCP WebSocket server started on port %d" % _port)
			return OK
		elif err == ERR_ALREADY_IN_USE:
			# Port is in use, try the next one
			current_port += 1
			attempt += 1
		else:
			# Some other error occurred
			print("Failed to start MCP WebSocket server: %d" % err)
			return err
	
	# If we get here, we couldn't find an available port
	print("Failed to start MCP WebSocket server: no available ports found after %d attempts" % max_attempts)
	return ERR_CANT_CONNECT


func stop_server() -> void:
	if is_server_active():
		# Close all client connections properly
		for client_id in peers.keys():
			if peers[client_id] != null:
				peers[client_id].close()
		peers.clear()

		# Stop TCP server
		tcp_server.stop()
		
		# Close all client connections
		for client_id in peers.keys():
			peers[client_id].close()
		peers.clear()
		pending_peers.clear()
		
		set_process(false)
		print("MCP WebSocket server stopped")


func poll() -> void:
	if not tcp_server.is_listening():
		return

	# Handle new connections
	if tcp_server.is_connection_available():
		var tcp = tcp_server.take_connection()
		if tcp == null:
			print("Failed to take TCP connection")
			return

		tcp.set_no_delay(true)  # Important for WebSocket

		print("New TCP connection accepted")
		var ws = WebSocketPeer.new()

		# Configure WebSocket peer
		ws.inbound_buffer_size = 64 * 1024 * 1024  # 64MB buffer
		ws.outbound_buffer_size = 64 * 1024 * 1024  # 64MB buffer
		ws.max_queued_packets = 4096

		# Accept the stream
		var err = ws.accept_stream(tcp)
		if err != OK:
			print("Failed to accept WebSocket stream: ", err)
			return

		# Generate client ID and store peer
		var client_id = randi() % (1 << 30) + 1
		peers[client_id] = ws
		print("WebSocket connection setup for client: ", client_id)

	# Process existing connections
	var to_remove = []

	for client_id in peers:
		var peer = peers[client_id]
		if peer == null:
			to_remove.append(client_id)
			continue

		peer.poll()
		var state = peer.get_ready_state()

		match state:
			WebSocketPeer.STATE_OPEN:
				# Process any available packets
				while peer.get_available_packet_count() > 0:
					var packet = peer.get_packet()
					_handle_packet(client_id, packet)

			WebSocketPeer.STATE_CONNECTING:
				print("Client %d still connecting..." % client_id)

			WebSocketPeer.STATE_CLOSING:
				print("Client %d closing connection..." % client_id)

			WebSocketPeer.STATE_CLOSED:
				print(
					(
						"Client %d connection closed. Code: %d, Reason: %s"
						% [client_id, peer.get_close_code(), peer.get_close_reason()]
					)
				)
				emit_signal("client_disconnected", client_id)
				to_remove.append(client_id)

	# Remove disconnected clients
	for r in to_remove:
		peers.erase(r)


func _handle_packet(client_id: int, packet: PackedByteArray) -> void:
	var text = packet.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(text)

	if parse_result == OK:
		var data = json.get_data()

		# Handle ping-pong for FastMCP
		if data.has("method") and data["method"] == "ping":
			var response = {"jsonrpc": "2.0", "id": data.get("id", 0), "result": "pong"}
			send_response(client_id, response)
			return

		print("Received command from client %d: %s" % [client_id, data])
		emit_signal("command_received", client_id, data)
	else:
		print(
			(
				"Error parsing JSON from client %d: %s at line %d"
				% [client_id, json.get_error_message(), json.get_error_line()]
			)
		)


func send_response(client_id: int, response: Dictionary) -> int:
	if not peers.has(client_id):
		print("Error: Client %d not found" % client_id)
		return ERR_DOES_NOT_EXIST

	var peer = peers[client_id]
	if peer == null:
		print("Error: Peer is null for client %d" % client_id)
		return ERR_INVALID_PARAMETER

	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Error: Client %d connection not open" % client_id)
		return ERR_UNAVAILABLE

	var json_text = JSON.stringify(response)
	var result = peer.send_text(json_text)

	if result != OK:
		print("Error sending response to client %d: %d" % [client_id, result])

	return result


func get_client_count() -> int:
	return peers.size()
