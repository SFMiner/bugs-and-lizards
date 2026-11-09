class_name NetClient
extends Node
## One WebSocket to the game server. Emits each decoded JSON message. Measures round-trip time.
## URL: on the web page served by the VPS -> wss://<host>/bugs-and-lizards/ws;
## on localhost or desktop -> ws://127.0.0.1:<DEFAULT_PORT>.

signal message_received(msg: Dictionary)
signal connected
signal disconnected

const PING_INTERVAL: float = 2.0
const CLIENT_MAX_BYTES: int = 4 * 1024 * 1024

var rtt_ms: int = -1
var _ws: WebSocketPeer = WebSocketPeer.new()
var _last_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
var _ping_timer: float = 0.0
var _url: String = ""


static func default_url() -> String:
	if OS.has_feature("web"):
		var host: String = str(JavaScriptBridge.eval("window.location.hostname", true))
		if host != "localhost" and host != "127.0.0.1" and host != "":
			var proto: String = str(JavaScriptBridge.eval("window.location.protocol", true))
			var scheme: String = "wss://" if proto == "https:" else "ws://"
			var hostport: String = str(JavaScriptBridge.eval("window.location.host", true))
			return scheme + hostport + Protocol.WS_PATH
	var env_url: String = OS.get_environment("BL_SERVER_URL")
	if env_url != "":
		return env_url
	return "ws://127.0.0.1:%d" % Protocol.DEFAULT_PORT


func connect_to(url: String = "") -> void:
	_url = url if url != "" else default_url()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = CLIENT_MAX_BYTES
	var err: Error = _ws.connect_to_url(_url)
	if err != OK:
		push_warning("net: connect_to_url failed: %s" % error_string(err))


func send(type: String, fields: Dictionary = {}) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(Protocol.encode(type, fields))


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func state_text() -> String:
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return "connecting"
		WebSocketPeer.STATE_OPEN:
			return "open"
		WebSocketPeer.STATE_CLOSING:
			return "closing"
	return "closed"


func url() -> String:
	return _url


func _process(delta: float) -> void:
	_ws.poll()
	var state: WebSocketPeer.State = _ws.get_ready_state()
	if state != _last_state:
		_last_state = state
		if state == WebSocketPeer.STATE_OPEN:
			_ping_timer = PING_INTERVAL
			connected.emit()
		elif state == WebSocketPeer.STATE_CLOSED:
			rtt_ms = -1
			disconnected.emit()
	if state != WebSocketPeer.STATE_OPEN:
		return
	while _ws.get_available_packet_count() > 0:
		var text: String = _ws.get_packet().get_string_from_utf8()
		var msg: Dictionary = Protocol.decode(text, CLIENT_MAX_BYTES)
		if msg.is_empty():
			continue
		if msg[Protocol.F_TYPE] == Protocol.PONG:
			rtt_ms = Time.get_ticks_msec() - int(msg.get(Protocol.F_TIME, 0))
		message_received.emit(msg)
	_ping_timer += delta
	if _ping_timer >= PING_INTERVAL:
		_ping_timer = 0.0
		send(Protocol.PING, {Protocol.F_TIME: Time.get_ticks_msec()})
