extends Node
## Autoload "Game": the one copy of /state, the week being viewed, and whether the
## player is busy (talking, in an overlay, changing rooms). Features talk to the
## backend through call() and act(); they never keep their own copy of money.

signal state_changed
signal failed(message: String)
signal event_fired(event: Dictionary)

var api := HoardApi.new()
var state: Dictionary = {}
var weeks_ago := 0
var busy := false


func _ready() -> void:
	add_child(api)
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
	_bind("interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_bind("ui_left", [KEY_A])
	_bind("ui_right", [KEY_D])
	_bind("ui_up", [KEY_W])
	_bind("ui_down", [KEY_S])


## Any route. Fires the response's _events (coins, items, money moved, level ups).
func call_api(method: String, path: String, body: Dictionary = {}, query: Dictionary = {}) -> Array:
	var res: Array = await api.request(method, path, query, body)
	if res[1] == "":
		for e: Dictionary in res[0].get("_events", []):
			event_fired.emit(e)
	return res


## POST something that changes the game, then reload /state.
func act(path: String, body: Dictionary = {}) -> Array:
	var res: Array = await call_api("POST", path, body)
	if res[1] == "":
		await refresh()
	return res


func refresh() -> void:
	var res: Array = await call_api("GET", "/state", {}, {"weeks_ago": weeks_ago})
	if res[1] != "":
		failed.emit(res[1])
		return
	state = res[0]
	state_changed.emit()


func change_week(delta: int) -> void:
	if state.is_empty():
		return
	var next := clampi(weeks_ago + delta, 0, int(state.history_weeks) - 1)
	if next != weeks_ago:
		weeks_ago = next
		refresh()


## Demo only: let days pass.
func advance_days(days: int = 1) -> Array:
	weeks_ago = 0
	return await act("/clock/advance", {"days": days})


func stock(symbol: String) -> Dictionary:
	for s: Dictionary in state.get("shop", {}).get("stocks", []):
		if s.symbol == symbol:
			return s
	return {}


func buy_stock(symbol: String, amount_cents: int) -> Array:
	return await act("/shop/stock", {"symbol": symbol, "amount_cents": amount_cents})


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
