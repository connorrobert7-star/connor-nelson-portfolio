class_name HoardApi
extends Node
## The only door to the backend. Every call returns [data: Dictionary, error: String].
## Desktop: HTTP to the FastAPI backend (uvicorn backend.app:app).
## Browser: the same Python engine running in the page under Pyodide, reached
## through window.hoard (see web/bridge.js). Same routes, same answers.


static func in_browser() -> bool:
	return OS.has_feature("web")


func base_url() -> String:
	var env := OS.get_environment("HOARD_BACKEND")
	if env != "":
		return env
	return ProjectSettings.get_setting("hoard/backend_url", "http://127.0.0.1:8000")


func request(method: String, path: String, query: Dictionary = {}, body: Dictionary = {}) -> Array:
	if in_browser():
		return await _browser(method, path, query, body)
	return await _http(method, path, query, body)


func _http(method: String, path: String, query: Dictionary, body: Dictionary) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var url := base_url() + path
	if not query.is_empty():
		var parts := PackedStringArray()
		for k: String in query:
			parts.append("%s=%s" % [k.uri_encode(), str(query[k]).uri_encode()])
		url += "?" + "&".join(parts)
	var verb := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	var payload := JSON.stringify(body) if method == "POST" else ""
	var err := http.request(url, ["Content-Type: application/json"], verb, payload)
	if err != OK:
		http.queue_free()
		return [{}, "Could not start request (%d)." % err]
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return [{}, "Backend not reachable at %s. Start it with: uvicorn backend.app:app" % base_url()]
	return _unpack(int(res[1]), JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()))


func _browser(method: String, path: String, query: Dictionary, body: Dictionary) -> Array:
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("hoard")
	if bridge == null:
		return [{}, "The in-page game engine didn't load."]
	var box := {"done": false, "out": ""}
	var cb := JavaScriptBridge.create_callback(
		func(args: Array) -> void:
			box.out = str(args[0])
			box.done = true
	)
	bridge.handle(method, path, JSON.stringify(query), JSON.stringify(body), cb)
	while not box.done:
		await get_tree().process_frame
	var envelope: Variant = JSON.parse_string(box.out)
	if not envelope is Dictionary:
		return [{}, "The in-page engine sent something that is not JSON."]
	return _unpack(int(envelope.status), envelope.body)


func _unpack(status: int, data: Variant) -> Array:
	if status != 200:
		var detail: String = str(data.get("detail", "")) if data is Dictionary else ""
		return [{}, detail if detail != "" else "Backend returned %d." % status]
	return [data, ""] if data is Dictionary else [{}, "Backend sent something that is not JSON."]
