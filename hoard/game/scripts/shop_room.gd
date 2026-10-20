class_name ShopRoom
extends Room
## Inside the shop. One shelf per stock; Marlo works the counter.

const SHELF_ROW := 2
const MARLO := Vector2i(13, 4)

var _shelf_symbols: Array[String] = []


func _init() -> void:
	map = [
		"WWWWWWWWWWWWWWWW",
		"WwwwwwwwwwwwwwwW",
		"WffffffffffwwwwW",
		"WffffffffffcfffW",
		"WffffffffffcfffW",
		"WffffffffffcfffW",
		"WffffffffffccccW",
		"WfffffrrrffffffW",
		"WfffffrrrffffffW",
		"WffffffffffffffW",
		"WWWWWWWddWWWWWWW",
	]


func build() -> void:
	super.build()
	add_npc("shopkeeper", MARLO, Vector2i(13, 7))
	for i in 10:
		var tile := Vector2i(1 + i, SHELF_ROW)
		place(preload("res://art/shelf.png"), Rect2i(tile, Vector2i.ONE))
		block(Rect2i(tile, Vector2i.ONE))
		add_interactable(
			tile_center(tile + Vector2i.DOWN),
			func() -> String: return _shelf_label(i),
			func() -> void: _shelf(i)
		)
	add_zone(Rect2i(1, 2, 10, 2), _prices_note, 0)


func _shelf_label(i: int) -> String:
	var s: Dictionary = Game.state.shop.stocks[i]
	return "%s  %s a share  (%s)" % [s.symbol, c(s.price_cents), hours(s.price_hours)]


func _prices_note() -> String:
	return "Prices are last Sunday's close and change once a week.\nWalk up to a shelf to look, or talk to Marlo at the counter."


func _shelf(i: int) -> void:
	var d: Dialogue = main.dialogue
	d.open("shopkeeper", Game.state.dialogue.shopkeeper.name)
	await _buy(Game.state.shop.stocks[i].symbol)
	d.close()


func talk(npc_id: String) -> void:
	var d: Dialogue = main.dialogue
	d.open(npc_id, Game.state.dialogue[npc_id].name)
	await d.say(Game.state.dialogue[npc_id].lines)
	while true:
		var pick: int = await d.ask("What can I do for you?", ["Buy shares", "What I own", "Never mind"])
		if pick == 0:
			var symbol: String = await _pick_stock()
			if symbol != "":
				await _buy(symbol)
		elif pick == 1:
			await d.say(_holdings_lines())
		else:
			break
	d.close()


func _pick_stock() -> String:
	var d: Dialogue = main.dialogue
	var stocks: Array = Game.state.shop.stocks
	var options: Array[String] = []
	for s: Dictionary in stocks:
		options.append("%s  %s" % [s.symbol, c(s.price_cents)])
	options.append("Back")
	var pick: int = await d.ask("Which one? Prices are per share.", options)
	return "" if pick < 0 or pick >= stocks.size() else str(stocks[pick].symbol)


func _buy(symbol: String) -> void:
	var d: Dialogue = main.dialogue
	var s := Game.stock(symbol)
	var shop: Dictionary = Game.state.shop
	var amounts: Array = shop.amounts
	var options: Array[String] = []
	var disabled: Array[bool] = []
	for a: Dictionary in amounts:
		options.append("%s  (%s)" % [c(a.amount_cents), hours(a.hours)])
		disabled.append(not a.affordable)
	options.append("Back")
	disabled.append(false)
	var owned := "You own %.4f shares." % float(s.owned_qty) if float(s.owned_qty) > 0 else "You don't own any yet."
	var prompt := "%s, %s. %s a share, or %s. %s\nYou can put in %s today. How much?" % [
		s.symbol, s.name, c(s.price_cents), hours(s.price_hours), owned, c(shop.can_spend_cents)
	]
	var pick: int = await d.ask(prompt, options, disabled)
	if pick < 0 or pick >= amounts.size():
		return
	var amount := int(amounts[pick].amount_cents)
	var confirm: int = await d.ask(
		"Put %s into %s? That's %s. It moves from checking to the brokerage." % [
			c(amount), symbol, hours(amounts[pick].hours)
		],
		["Buy", "Not now"]
	)
	if confirm != 0:
		return
	var res: Array = await Game.buy_stock(symbol, amount)
	if res[1] != "":
		await d.say([str(res[1])])
		return
	var note := (
		"Simulated for now. Real money moves once accounts are connected."
		if res[0].status == "simulated"
		else "It's on its way. Transfers take a day or two to land."
	)
	await d.say(["Done. That's %.4f shares of %s." % [float(res[0].qty), symbol], note])


func _holdings_lines() -> Array[String]:
	var lines: Array[String] = []
	for s: Dictionary in Game.state.shop.stocks:
		if float(s.owned_qty) > 0:
			lines.append("%s: %.4f shares, about %s at last Sunday's price." % [
				s.symbol, float(s.owned_qty), c(float(s.owned_qty) * float(s.price_cents))
			])
	if lines.is_empty():
		lines.append("Nothing yet.")
	var joined: Array[String] = []
	for i in range(0, lines.size(), 3):
		joined.append("\n".join(PackedStringArray(lines.slice(i, i + 3))))
	return joined
