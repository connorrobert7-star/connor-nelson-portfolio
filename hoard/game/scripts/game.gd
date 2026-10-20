extends Node
## Autoload "Game": the one copy of /state, the week being viewed, and whether
## the player is busy (talking, changing rooms).

signal state_changed
signal failed(message: String)

var api := HoardApi.new()
var state: Dictionary = {}
var weeks_ago := 0
var busy := false
var _demo_orders: Array[Dictionary] = []


func _ready() -> void:
	add_child(api)
	RenderingServer.set_default_clear_color(Color(0.12, 0.11, 0.1))
	_bind("interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_bind("ui_left", [KEY_A])
	_bind("ui_right", [KEY_D])
	_bind("ui_up", [KEY_W])
	_bind("ui_down", [KEY_S])


func refresh() -> void:
	var res: Array = await api.get_state(weeks_ago)
	if res[1] != "":
		failed.emit(res[1])
		return
	state = res[0]
	_apply_demo_orders()
	state_changed.emit()


func change_week(delta: int) -> void:
	if state.is_empty():
		return
	var next := clampi(weeks_ago + delta, 0, int(state.history_weeks) - 1)
	if next != weeks_ago:
		weeks_ago = next
		refresh()


func stock(symbol: String) -> Dictionary:
	for s: Dictionary in state.shop.stocks:
		if s.symbol == symbol:
			return s
	return {}


func buy_stock(symbol: String, amount_cents: int) -> Array:
	if HoardApi.is_demo():
		return await _demo_buy(symbol, amount_cents)
	var res: Array = await api.buy_stock(symbol, amount_cents)
	if res[1] == "":
		await refresh()
	return res


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


# --- web demo only -------------------------------------------------------------
# There is no backend in the browser, so the demo mirrors the shop's limit check
# against the snapshot and keeps orders in memory. Nothing is saved.

func _demo_buy(symbol: String, amount_cents: int) -> Array:
	if amount_cents > int(state.shop.can_spend_cents):
		return [{}, "That's more than you can put in today."]
	var qty := float(amount_cents) / float(stock(symbol).price_cents)
	_demo_orders.append({"symbol": symbol, "amount_cents": amount_cents, "qty": qty, "created": state.today})
	await refresh()
	return [{"symbol": symbol, "amount_cents": amount_cents, "qty": qty, "status": "demo"}, ""]


func _apply_demo_orders() -> void:
	var shop: Dictionary = state.shop
	for o: Dictionary in _demo_orders:
		shop.can_spend_cents = int(shop.can_spend_cents) - int(o.amount_cents)
		state.extra.extra_cents = int(state.extra.extra_cents) - int(o.amount_cents)
		shop.recent_orders.push_front(o)
		var s := stock(o.symbol)
		s.owned_qty = float(s.owned_qty) + float(o.qty)
	for a: Dictionary in shop.amounts:
		a.affordable = int(a.amount_cents) <= int(shop.can_spend_cents)
