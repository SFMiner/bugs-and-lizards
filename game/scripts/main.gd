extends Node
## Entry point. Server with `-- --server` (headless on the VPS), otherwise the client.
## Client routing: `?campus` in the page URL (or `--campus` on desktop) opens the campus check.

const BOOT_LINE: String = "bugs-and-lizards: boot ok"


func _ready() -> void:
	print(BOOT_LINE)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--server"):
		_start_server(args)
	else:
		_start_client(args)


func _start_server(args: PackedStringArray) -> void:
	var port: int = Protocol.DEFAULT_PORT
	for a: String in args:
		if a.begins_with("--port="):
			port = int(a.get_slice("=", 1))
	var script: GDScript = load("res://scripts/server/server_main.gd")
	var server: Node = script.new()
	server.name = "Server"
	add_child(server)
	server.call("start", port)


func _start_client(args: PackedStringArray) -> void:
	var path: String = "res://scripts/client/campus_check.gd"
	var script: GDScript = load(path)
	var node: Node = script.new()
	node.name = "Client"
	add_child(node)


## Query string of the page on web ("" on desktop), without the leading "?".
static func page_query() -> String:
	if not OS.has_feature("web"):
		return ""
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	var s: String = str(q) if q != null else ""
	return s.trim_prefix("?")
