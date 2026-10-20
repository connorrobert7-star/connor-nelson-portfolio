class_name HoardApi
extends Node
## Talks to the FastAPI backend. The game never calls Plaid or SnapTrade.
## A web build can't reach a backend on your machine, so it reads the /state
## snapshots in res://demo/ instead (tools/export_demo_state.py writes them).
## Every call returns [data: Dictionary, error: String].


static func is_demo() -> bool:
	return OS.has_feature("web")


func base_url() -> String:
	var env := OS.get_environment("HOARD_BACKEND")
	if env != "":
		return env
	return ProjectSettings.get_setting("hoard/backend_url", "http://127.0.0.1:8000")


func get_state(weeks_ago: int) -> Array:
	if is_demo():
		var data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://demo/state_%d.json" % weeks_ago)
		)
		return [data, ""] if data is Dictionary else [{}, "Demo data missing for week %d." % weeks_ago]
	return await _request(HTTPClient.METHOD_GET, "/state?weeks_ago=%d" % weeks_ago)


func buy_stock(symbol: String, amount_cents: int) -> Array:
	return await _request(
		HTTPClient.METHOD_POST, "/shop/stock", {"symbol": symbol, "amount_cents": amount_cents}
	)


func _request(method: HTTPClient.Method, path: String, body: Variant = null) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url() + path, ["Content-Type: application/json"], method, payload)
	if err != OK:
		http.queue_free()
		return [{}, "Could not start request (%d)." % err]
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return [{}, "Backend not reachable at %s. Start it with: uvicorn backend.app:app" % base_url()]
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if res[1] != 200:
		var detail: String = str(data.get("detail", "")) if data is Dictionary else ""
		return [{}, detail if detail != "" else "Backend returned %d." % res[1]]
	return [data, ""] if data is Dictionary else [{}, "Backend sent something that is not JSON."]
