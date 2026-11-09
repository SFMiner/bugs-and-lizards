extends Node
## Headless WebSocket server: TCPServer + WebSocketPeer.accept_stream, plain JSON messages (protocol.gd).
## M1: accepts connections and answers PING with PONG. Session logic arrives in M3.

const POLL_FPS: int = 60

var _tcp: TCPServer = TCPServer.new()
var _peers: Dictionary = {} # int id -> WebSocketPeer
var _next_id: int = 1


func start(port: int) -> void:
	Engine.max_fps = POLL_FPS
	var err: Error = _tcp.listen(port, "127.0.0.1")
	if err != OK:
		push_error("server: cannot listen on %d (%s)" % [port, error_string(err)])
		get_tree().quit(1)
		return
	print("server: listening on 127.0.0.1:%d" % port)


func _process(_delta: float) -> void:
	while _tcp.is_connection_available():
		var conn: StreamPeerTCP = _tcp.take_connection()
		var ws: WebSocketPeer = WebSocketPeer.new()
		ws.inbound_buffer_size = Protocol.MAX_MESSAGE_BYTES * 2
		if ws.accept_stream(conn) == OK:
			_peers[_next_id] = ws
			_next_id += 1
	var closed: Array[int] = []
	for id: int in _peers:
		var ws: WebSocketPeer = _peers[id]
		ws.poll()
		var state: WebSocketPeer.State = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt: PackedByteArray = ws.get_packet()
				if not ws.was_string_packet():
					continue
				var msg: Dictionary = Protocol.decode(pkt.get_string_from_utf8())
				if not msg.is_empty():
					_on_message(id, msg)
		elif state == WebSocketPeer.STATE_CLOSED:
			closed.append(id)
	for id: int in closed:
		_peers.erase(id)
		_on_disconnect(id)


func send(id: int, type: String, fields: Dictionary = {}) -> void:
	var ws: WebSocketPeer = _peers.get(id)
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(Protocol.encode(type, fields))


func _on_message(id: int, msg: Dictionary) -> void:
	match msg[Protocol.F_TYPE]:
		Protocol.PING:
			send(id, Protocol.PONG, {Protocol.F_TIME: msg.get(Protocol.F_TIME, 0)})


func _on_disconnect(_id: int) -> void:
	pass
