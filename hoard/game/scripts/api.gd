class_name HoardApi
extends Node
## Talks to the FastAPI backend. The game never calls Plaid or SnapTrade.

signal state_loaded(state: Dictionary)
signal failed(message: String)

var _http := HTTPRequest.new()


func _ready() -> void:
	add_child(_http)
	_http.timeout = 5.0
	_http.request_completed.connect(_on_completed)


func base_url() -> String:
	var env := OS.get_environment("HOARD_BACKEND")
	if env != "":
		return env
	return ProjectSettings.get_setting("hoard/backend_url", "http://127.0.0.1:8000")


func fetch_state(weeks_ago: int) -> void:
	_http.cancel_request()
	var err := _http.request("%s/state?weeks_ago=%d" % [base_url(), weeks_ago])
	if err != OK:
		failed.emit("Could not start request (%d)." % err)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Backend not reachable at %s. Start it with: uvicorn backend.app:app" % base_url())
		return
	if code != 200:
		failed.emit("Backend returned %d." % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary:
		state_loaded.emit(data)
	else:
		failed.emit("Backend sent something that is not JSON.")
