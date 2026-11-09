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
		var shot: String = OS.get_environment("BL_SHOT") # desktop debug: save a screenshot and quit
		if shot != "" and not OS.has_feature("web"):
			for i: int in 120:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(shot)
			get_tree().quit()


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
	var query: String = page_query()
	var flags: PackedStringArray = query.split("&", false)
	if flags.has("campus") or args.has("--campus"):
		var script: GDScript = load("res://scripts/client/campus_check.gd")
		var node: Node = script.new()
		node.name = "Client"
		add_child(node)
		return
	var app: ClientApp = ClientApp.new()
	app.name = "Client"
	app.teacher_mode = flags.has("teacher") or args.has("--teacher")
	add_child(app)


## Query string of the page on web ("" on desktop), without the leading "?".
static func page_query() -> String:
	if not OS.has_feature("web"):
		return ""
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	var s: String = str(q) if q != null else ""
	return s.trim_prefix("?")
