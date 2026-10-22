class_name ShopRoom
extends Room
## Inside the shop: a dark little store lit by hanging lanterns and the moon through two
## windows. One shelf per stock, each with its price tag pinned on (the symbol, last Sunday's
## close, and the hours of work it costs); Marlo works his stall by the door, last week's
## calendar pinned behind him with Sunday ringed, a big clock ticking on the back wall.
## Buys are quiet: the register clunks and Marlo nods. No panels, no prompts.

const MARLO := Vector2i(13, 5)
const MAP: Array[String] = [
	"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WWWWWWWWWWWWWWddWWWWWWWWWWWWWW",
]
## Shelf centers: five against the back wall, five on the aisle in front of them (with a
## walkway through the middle).
const SHELF_X: Array[int] = [-72, -24, 24, 72, 120]
const AISLE_X: Array[int] = [-80, -34, 50, 96, 142]
const ROW_A := -6  # the wall shelves' feet: a step out from the wall, their tops clear of the HUD
const ROW_B := 64  # the aisle shelves' feet
const SHELF_H := 52
const WOOD := Color("4a2c22")
const WALLPAPER := Color("2b2140")
const TEAL := Color("5fe0c0")
# Goods on the shelves: 0x72 flasks, chests and coins (sheet rects).
const GOODS: Array[Rect2] = [
	Rect2(288, 336, 16, 16), Rect2(304, 336, 16, 16), Rect2(320, 336, 16, 16), Rect2(336, 336, 16, 16),
	Rect2(288, 352, 16, 16), Rect2(304, 352, 16, 16), Rect2(320, 352, 16, 16), Rect2(336, 352, 16, 16),
]
const WINDOWS: Array[float] = [160.0, 236.0]
const SND_CLUNK := "kenney-impact-sounds/Audio/impactMetal_light_002.ogg"
const SND_DRAWER := "kenney-casino-audio/Audio/chips-handle-3.ogg"

var marlo: Sprite2D
var register := Node2D.new()
var clock := Node2D.new()
var _marlo_y := 0.0
var _nod := 0.0
var _drawer := 0.0


func _init() -> void:
	map = MAP
	origin = Vector2i(-7, -6)


func build() -> void:
	super.build()
	block(Rect2i(-6, -2, 15, 2))  # the wall shelves (and the gap behind them)
	block(Rect2i(10, 2, 7, 5))  # the stall and its counter
	block(Rect2i(-6, 7, 3, 3))  # crates by the left wall
	block(Rect2i(18, 7, 4, 3))  # barrels by the right wall
	room_under.draw.connect(_draw_floor)
	room_walls.draw.connect(_draw_walls)
	for i in 10:
		var wall := i < 5
		var x := SHELF_X[i % 5] if wall else AISLE_X[i % 5]
		var feet := ROW_A if wall else ROW_B
		if not wall:
			block(Rect2i(floori((x - 14) / 16.0), 3, floori((x + 13) / 16.0) - floori((x - 14) / 16.0) + 1, 1))
		var shelf := Shelf.new()
		shelf.position = Vector2(x, feet)
		shelf.index = i
		props.add_child(shelf)
		Kit.shadow(room_pools, Vector2(x, feet), 40, 0.4)
		add_interactable(Vector2(x, feet + 22 if wall else feet + 20), func() -> String: return "", func() -> void: _shelf(i))
		room_hotspot(Rect2(x - 20, feet - SHELF_H - 2, 40, SHELF_H + 12))
	_build_stall()
	_build_dressing()
	_build_light()


func _build_stall() -> void:
	var back := StallBack.new()
	back.position = Vector2(216, 60)
	props.add_child(back)
	var stall := Stall.new()
	stall.position = Vector2(216, 112)
	props.add_child(stall)
	marlo = add_npc("shopkeeper", MARLO, Vector2i(13, 7))
	_marlo_y = marlo.offset.y
	room_hotspot(Rect2(196, 56, 40, 60))
	Kit.shadow(room_pools, marlo.position, 20, 0.45)
	var cal := Calendar.new()
	cal.position = Vector2(-48, -26)
	back.add_child(cal)
	register.position = Vector2(30, -20)
	register.draw.connect(_draw_register)
	stall.add_child(register)


func _build_dressing() -> void:
	clock.position = Vector2(196, -28)
	clock.draw.connect(_draw_clock)
	props.add_child(clock)
	Kit.shadow(room_pools, Vector2(196, -28), 22, 0.4)
	# Crates and a barrel by the left wall; barrels and a plant by the right.
	var crate := Kit.region(Kit.SHEET, Rect2(288, 408, 16, 24))
	for p: Vector2 in [Vector2(-96, 116), Vector2(-80, 116), Vector2(-88, 102), Vector2(-96, 140), Vector2(-64, 140)]:
		var s := Kit.put(crate, p, props)
		s.offset = Vector2(0, -24)
		s.position.y += 24
		Kit.shadow(room_pools, p + Vector2(8, 24), 18, 0.35)
	for p: Vector2 in [Vector2(304, 140), Vector2(320, 140), Vector2(336, 140), Vector2(312, 156), Vector2(328, 156)]:
		var b := Node2D.new()
		b.position = p
		b.draw.connect(func() -> void: _barrel(b))
		props.add_child(b)
		Kit.shadow(room_pools, p, 16, 0.4)
	var plant := Kit.put(Kit.indoor(16, 0), Vector2(-104, 92), props)
	plant.offset = Vector2(0, -16)
	plant.position.y += 16
	var plant2 := Kit.put(Kit.indoor(17, 0), Vector2(332, 44), props)
	plant2.offset = Vector2(0, -16)
	plant2.position.y += 16
	# A rug inside the door.
	var rug := Node2D.new()
	rug.position = Vector2(128, 140)
	rug.draw.connect(func() -> void:
		rug.draw_rect(Rect2(-26, -12, 52, 22), Color("5a1c26"))
		rug.draw_rect(Rect2(-24, -10, 48, 18), Color("7a2a32"))
		rug.draw_rect(Rect2(-22, -8, 44, 14), Color("5a1c26"))
		for k in 5:
			rug.draw_rect(Rect2(-16 + k * 8, -2, 2, 2), Color("c9a24a"))
		for k in 9:
			rug.draw_rect(Rect2(-24 + k * 6, 10, 1, 2), Color("c9a24a").darkened(0.3))
	)
	room_under.add_child(rug)


func _build_light() -> void:
	room_vignette(Vector2(150, 50), 0.95)
	room_lantern(Vector2(0, 40), 50)
	room_lantern(Vector2(-56, 136), 50, Kit.WARM, 56)
	room_lantern(Vector2(300, 100), 50, Kit.WARM, 60)
	# An oil lamp on the counter, lighting Marlo from the side.
	var oil := Kit.put(Kit.region(Kit.EXT, Rect2(128, 400, 16, 16)), Vector2(170, 92), props, true)
	oil.offset = Vector2(0, -8)
	var halo := Kit.glow(oil, Vector2(0, -12), Kit.WARM, 20, 0.6)
	room_flicker(halo, 0.2, 7.0)
	room_flicker(Kit.glow(room_pools, Vector2(190, 118), Kit.WARM, 56, 0.4, 0.55), 0.1, 5.0)
	# Moonlight through the windows: a cool shaft onto the floor, dust turning in it.
	for wx: float in WINDOWS:
		_moonbeam(Vector2(wx, -46))
		Kit.glow(room_walls, Vector2(wx, -66), Kit.MOON, 26, 0.28)
	room_motes(Rect2(-90, -30, 420, 170), Kit.WARM, 16)
	room_motes(Rect2(150, -30, 60, 60), Kit.MOON, 6)


func _moonbeam(top: Vector2) -> void:
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		top + Vector2(-13, 0), top + Vector2(13, 0), top + Vector2(-8, 74), top + Vector2(-42, 74)
	])
	beam.vertex_colors = PackedColorArray([
		Color(Kit.MOON, 0.20), Color(Kit.MOON, 0.20), Color(Kit.MOON, 0.0), Color(Kit.MOON, 0.0)
	])
	beam.material = Kit.additive()
	room_pools.add_child(beam)
	Kit.glow(room_pools, top + Vector2(-25, 70), Kit.MOON, 26, 0.16, 0.5)


# --- state ------------------------------------------------------------------------------

func dress() -> void:
	var stocks: Array = Game.state.get("shop", {}).get("stocks", [])
	for i in mini(stocks.size(), 10):
		var s: Dictionary = stocks[i]
		var wall := i < 5
		var tag := PriceTag.new()
		tag.position = Vector2(SHELF_X[i % 5] if wall else AISLE_X[i % 5], (ROW_A if wall else ROW_B) + 1)
		tag.symbol = str(s.symbol)
		tag.price = _price(int(s.price_cents))
		tag.hours = "%.1fh" % float(s.price_hours)
		tag.owned = float(s.get("owned_qty", 0)) > 0
		tag.seed = i * 1.37
		dynamic.add_child(tag)


static func _price(cents: int) -> String:
	return "$%d" % (cents / 100) if cents % 100 == 0 else Money.fmt(cents)


func _process(delta: float) -> void:
	super._process(delta)
	if marlo:
		# Marlo breathes: a one-pixel rise and fall; a nod dips his head twice.
		var breath := 1.0 if fmod(_room_t, 2.6) < 1.3 else 0.0
		var nod := 0.0
		if _nod > 0.0:
			_nod = maxf(0.0, _nod - delta)
			nod = 2.0 * absf(sin((0.9 - _nod) * TAU / 0.45)) if _nod < 0.9 else 0.0
		marlo.offset.y = _marlo_y - breath + nod
	if _drawer > 0.0:
		_drawer = maxf(0.0, _drawer - delta)
	register.queue_redraw()
	clock.queue_redraw()


func _shelf(i: int) -> void:
	var stocks: Array = Game.state.get("shop", {}).get("stocks", [])
	if i >= stocks.size():
		return
	var d: Dialogue = main.dialogue
	d.open("shopkeeper", Game.state.dialogue.shopkeeper.name)
	await _buy(stocks[i].symbol)
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
	# Quiet: the register clunks, the drawer slides, Marlo nods. Nothing celebrates.
	_drawer = 0.6
	_nod = 0.9
	Kit.play(SND_CLUNK, 0.8, -10.0)
	Kit.play(SND_DRAWER, 1.0, -14.0)
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


# --- drawing ----------------------------------------------------------------------------

func _draw_floor() -> void:
	var r := room_rect()
	Kit.planks(room_under, Rect2(r.position.x + 16, -32, r.size.x - 32, 192), Color("4a3028"))
	# Worn path from the door to the stall, a little lighter.
	room_under.draw_rect(Rect2(112, 120, 32, 40), Color(1, 0.9, 0.7, 0.04))


func _draw_walls() -> void:
	var r := room_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	# Wallpaper: plum with a faint diamond print, dark wood wainscot, a rail.
	room_walls.draw_rect(Rect2(x0, -96, r.size.x, 64), WALLPAPER)
	var y := -92
	while y < -52:
		var x := x0 + (8 if (y / 8) % 2 == 0 else 0)
		while x < x1:
			room_walls.draw_rect(Rect2(x, y, 1, 1), WALLPAPER.lightened(0.18))
			room_walls.draw_rect(Rect2(x - 1, y + 1, 3, 1), WALLPAPER.lightened(0.08))
			room_walls.draw_rect(Rect2(x, y + 2, 1, 1), WALLPAPER.lightened(0.18))
			x += 16
		y += 8
	room_walls.draw_rect(Rect2(x0, -50, r.size.x, 18), WOOD.darkened(0.2))
	var px := x0
	while px < x1:
		room_walls.draw_rect(Rect2(px + 2, -47, 28, 12), WOOD.darkened(0.05))
		room_walls.draw_rect(Rect2(px + 2, -47, 28, 1), WOOD.lightened(0.15))
		px += 32
	room_walls.draw_rect(Rect2(x0, -52, r.size.x, 3), WOOD.lightened(0.1))
	room_walls.draw_rect(Rect2(x0, -33, r.size.x, 1), Color(0, 0, 0, 0.5))
	# Shadow room_under the wall line, on the floor.
	for i in 6:
		room_walls.draw_rect(Rect2(x0, -32 + i, r.size.x, 1), Color(0, 0, 0, 0.3 - i * 0.05))
	# Windows: night sky, the moon, a cross of mullions.
	for wx: float in WINDOWS:
		_window(Vector2(wx - 14, -84))
	# Ceiling beams and the side and bottom room_walls.
	Kit.beam(room_walls, x0, x1, -96, Color("2e1c16"))
	room_walls.draw_rect(Rect2(x0, -32, 16, 192), Color("120c12"))
	room_walls.draw_rect(Rect2(x0 + 15, -32, 1, 192), Color("3a2a26"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 16, 192), Color("120c12"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 1, 192), Color("3a2a26"))
	room_walls.draw_rect(Rect2(x0, 160, 112 - x0, 16), Color("120c12"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 144, 16), Color("120c12"))
	room_walls.draw_rect(Rect2(x0 + 16, 160, 112 - x0 - 16, 1), Color("3a2a26"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 160, 1), Color("3a2a26"))
	# The doorway: a warm threshold and the frame.
	room_walls.draw_rect(Rect2(112, 160, 32, 16), Color("1c1418"))
	room_walls.draw_rect(Rect2(110, 156, 2, 20), WOOD)
	room_walls.draw_rect(Rect2(144, 156, 2, 20), WOOD)


func _window(at: Vector2) -> void:
	var w := 28.0
	var h := 34.0
	room_walls.draw_rect(Rect2(at - Vector2(3, 3), Vector2(w + 6, h + 6)), WOOD.darkened(0.3))
	room_walls.draw_rect(Rect2(at - Vector2(2, 2), Vector2(w + 4, h + 4)), WOOD)
	for i in int(h):
		room_walls.draw_rect(Rect2(at.x, at.y + i, w, 1), Color("0e1430").lerp(Color("2a3a6a"), float(i) / h))
	room_walls.draw_circle(at + Vector2(8, 9), 4.0, Color("f4ecd0"))
	room_walls.draw_circle(at + Vector2(10, 8), 3.0, Color("2a3a6a").lerp(Color("f4ecd0"), 0.15))
	for s: Vector2 in [Vector2(20, 5), Vector2(23, 14), Vector2(4, 22), Vector2(17, 26)]:
		room_walls.draw_rect(Rect2(at + s, Vector2.ONE), Color(1, 1, 1, 0.8))
	room_walls.draw_rect(Rect2(at.x + w / 2 - 1, at.y, 2, h), WOOD)
	room_walls.draw_rect(Rect2(at.x, at.y + h / 2 - 1, w, 2), WOOD)
	room_walls.draw_rect(Rect2(at.x - 4, at.y + h + 2, w + 8, 3), WOOD.lightened(0.1))


func _draw_clock() -> void:
	var c := clock
	var wood := Color("3a2018")
	# A grandfather clock: hood, face, the long case with a window on the pendulum.
	c.draw_rect(Rect2(-8, -58, 16, 58), wood)
	c.draw_rect(Rect2(-9, -60, 18, 4), wood.lightened(0.15))
	c.draw_rect(Rect2(-8, -58, 1, 58), wood.lightened(0.2))
	c.draw_rect(Rect2(-10, -2, 20, 2), wood.darkened(0.3))
	var face := Vector2(0, -48)
	c.draw_circle(face, 6.0, Color("c9a24a"))
	c.draw_circle(face, 5.0, Color("f1e6c8"))
	var now := Time.get_time_dict_from_system()
	var m := float(now.minute) + float(now.second) / 60.0
	var hr := float(int(now.hour) % 12) + m / 60.0
	c.draw_line(face, face + Vector2.from_angle(hr / 12.0 * TAU - PI / 2) * 3.0, Kit.INK, 1.0)
	c.draw_line(face, face + Vector2.from_angle(m / 60.0 * TAU - PI / 2) * 4.5, Kit.INK, 1.0)
	c.draw_rect(Rect2(face, Vector2.ONE), Color("8a2a2a"))
	c.draw_rect(Rect2(-4, -38, 8, 30), Color("120a10"))
	var swing := sin(_room_t * PI) * 2.5
	var bob := Vector2(swing, -14).round()
	c.draw_line(Vector2(0, -37), bob, Color("c9a24a"), 1.0)
	c.draw_circle(bob, 2.0, Color("e2bf5a"))
	c.draw_rect(Rect2(bob + Vector2(-1, -1), Vector2.ONE), Color("fff2b0"))


func _barrel(b: Node2D) -> void:
	var wood := Color("6a3e26")
	b.draw_rect(Rect2(-6, -15, 12, 15), wood)
	b.draw_rect(Rect2(-7, -12, 14, 9), wood)
	b.draw_rect(Rect2(-5, -15, 2, 15), wood.lightened(0.15))
	b.draw_rect(Rect2(3, -15, 2, 15), wood.darkened(0.25))
	for y: int in [-13, -4]:
		b.draw_rect(Rect2(-7, y, 14, 1), Color("2a2224"))
	b.draw_rect(Rect2(-5, -16, 10, 1), wood.lightened(0.3))


func _draw_register() -> void:
	var r := register
	var brass := Color("b8893a")
	var out := roundf(_drawer / 0.6 * 3.0)
	r.draw_rect(Rect2(-7, -2 + out, 14, 3), brass.darkened(0.35))
	r.draw_rect(Rect2(-7, -10, 14, 9), brass)
	r.draw_rect(Rect2(-7, -10, 14, 1), brass.lightened(0.35))
	r.draw_rect(Rect2(-5, -8, 10, 3), Color("1a1410"))
	r.draw_rect(Rect2(-4, -7, 1, 1), Color("7fffd0"))
	r.draw_rect(Rect2(-2, -7, 1, 1), Color("7fffd0"))
	r.draw_rect(Rect2(0, -7, 1, 1), Color("7fffd0"))
	for k in 3:
		r.draw_rect(Rect2(-5 + k * 4, -4, 2, 1), brass.lightened(0.2))


# --- pieces -----------------------------------------------------------------------------

## A dark wood shelf of goods; the price tag is pinned on its front (PriceTag).
class Shelf extends Node2D:
	var index := 0

	func _ready() -> void:
		var boards := [-46, -32, -18]
		for b in boards.size():
			for k in 2:
				var g: Rect2 = ShopRoom.GOODS[(index * 3 + b * 2 + k) % ShopRoom.GOODS.size()]
				var s := Room.Kit.put(Room.Kit.region(Room.Kit.SHEET, g), Vector2(-14 + k * 13, int(boards[b]) - 15), self)
				s.z_index = 0

	func _draw() -> void:
		var w := ShopRoom.WOOD
		var h := ShopRoom.SHELF_H
		draw_rect(Rect2(-16, -h, 32, h), w.darkened(0.3))
		draw_rect(Rect2(-14, -h + 4, 28, h - 6), Color("1a1016"))
		for y: int in [-46, -32, -18]:
			draw_rect(Rect2(-15, y, 30, 2), w.lightened(0.1))
			draw_rect(Rect2(-15, y + 2, 30, 1), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-17, -h - 2, 34, 3), w.lightened(0.15))
		draw_rect(Rect2(-17, -h - 2, 34, 1), w.lightened(0.35))
		draw_rect(Rect2(-16, -h, 1, h), w.lightened(0.2))
		draw_rect(Rect2(15, -h, 1, h), w.darkened(0.5))
		draw_rect(Rect2(-16, -2, 32, 2), w.darkened(0.45))


## A paper price tag on a string: the symbol, last Sunday's close and the hours of work.
class PriceTag extends Node2D:
	var symbol := ""
	var price := ""
	var hours := ""
	var owned := false
	var seed := 0.0
	var _sway := 0

	func _ready() -> void:
		var paper := Node2D.new()
		paper.name = "paper"
		add_child(paper)
		paper.draw.connect(func() -> void: _paper(paper))
		Room.Kit.write(paper, symbol, Vector2(0, -11), Color("1d3a5a"))
		Room.Kit.write(paper, price, Vector2(0, -3), Room.Kit.INK)
		Room.Kit.write(paper, hours, Vector2(0, 5), Color("8a4a2a"))

	func _process(_delta: float) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var s := 1 if sin(t * 1.3 + seed) > 0.75 else 0
		if s != _sway:
			_sway = s
			(get_node("paper") as Node2D).position.x = s

	func _paper(n: Node2D) -> void:
		var w := roundf(maxf(26.0, maxf(price.length(), symbol.length()) * 6.0))
		var top := -17.0
		var h := 27.0
		n.draw_line(Vector2(-6, top - 4), Vector2(-w / 2 + 3, top), Color("d8c8a8"), 1.0)
		n.draw_line(Vector2(6, top - 4), Vector2(w / 2 - 3, top), Color("d8c8a8"), 1.0)
		n.draw_rect(Rect2(-w / 2 + 1, top + 1, w, h), Color(0, 0, 0, 0.5))
		n.draw_rect(Rect2(-w / 2, top, w, h), Color("efe2c4"))
		n.draw_rect(Rect2(-w / 2, top, w, 1), Color("fff6e0"))
		n.draw_rect(Rect2(-w / 2, top + h - 1, w, 1), Color("c9b48e"))
		n.draw_rect(Rect2(-w / 2 + 1, top + 1, 1, 1), Color("c9a24a"))
		n.draw_rect(Rect2(w / 2 - 2, top + 1, 1, 1), Color("c9a24a"))
		if owned:
			# A small teal corner: you hold some of this one.
			n.draw_rect(Rect2(w / 2 - 4, top, 4, 4), ShopRoom.TEAL)


## The board behind Marlo: small wares on two shelves and last week's calendar.
class StallBack extends Node2D:
	func _draw() -> void:
		var w := ShopRoom.WOOD
		draw_rect(Rect2(-54, -36, 108, 70), w.darkened(0.35))
		draw_rect(Rect2(-52, -34, 104, 66), Color("1d1218"))
		for y: int in [-12, 6]:
			draw_rect(Rect2(22, y, 28, 2), w.lightened(0.1))
			draw_rect(Rect2(22, y + 2, 28, 1), Color(0, 0, 0, 0.5))
		var jars := [Color("d05050"), Color("50b0d0"), Color("e0c050"), Color("70d080")]
		for k in 4:
			draw_rect(Rect2(24 + k * 6, -18, 4, 6), jars[k])
			draw_rect(Rect2(24 + k * 6, -18, 4, 1), jars[k].lightened(0.4))
			draw_rect(Rect2(24 + k * 6, 0, 4, 6), jars[(k + 2) % 4])
			draw_rect(Rect2(24 + k * 6, 0, 4, 1), jars[(k + 2) % 4].lightened(0.4))


## Marlo's stall: an awning in the shop's teal, two posts and the counter you talk to him
## across (drawn in front of him).
class Stall extends Node2D:
	func _draw() -> void:
		var w := ShopRoom.WOOD
		draw_rect(Rect2(-58, -96, 4, 96), w)
		draw_rect(Rect2(54, -96, 4, 96), w)
		draw_rect(Rect2(-58, -96, 1, 96), w.lightened(0.25))
		draw_rect(Rect2(54, -96, 1, 96), w.lightened(0.25))
		for k in 15:
			var col := ShopRoom.TEAL.darkened(0.2) if k % 2 == 0 else Color("efe2c4").darkened(0.1)
			draw_rect(Rect2(-60 + k * 8, -106, 8, 12), col)
			draw_rect(Rect2(-59 + k * 8, -94, 6, 2), col)
			draw_rect(Rect2(-58 + k * 8, -92, 4, 1), col)
			draw_rect(Rect2(-60 + k * 8, -106, 8, 1), col.lightened(0.3))
		draw_rect(Rect2(-60, -91, 120, 3), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(-58, -20, 116, 20), w)
		draw_rect(Rect2(-60, -22, 120, 4), w.lightened(0.18))
		draw_rect(Rect2(-60, -22, 120, 1), w.lightened(0.4))
		for k in 7:
			draw_rect(Rect2(-54 + k * 16, -14, 12, 10), w.darkened(0.15))
			draw_rect(Rect2(-54 + k * 16, -14, 12, 1), w.darkened(0.4))
		draw_rect(Rect2(-58, -1, 116, 1), Color(0, 0, 0, 0.5))


## Last week on a calendar pinned to the back board: seven days, Sunday ringed. Prices on
## the tags are that Sunday's close.
class Calendar extends Node2D:
	func _ready() -> void:
		var today := str(Game.state.get("today", ""))
		var day := 0
		if today != "":
			var unix := Time.get_unix_time_from_datetime_string(today)
			var wd := int(Time.get_datetime_dict_from_unix_time(unix).weekday)
			var sunday := unix - 86400 * (wd if wd > 0 else 7)
			day = int(Time.get_datetime_dict_from_unix_time(sunday).day)
		if day > 0:
			Room.Kit.write(self, str(day), Vector2(13, 13), Room.Kit.INK)

	func _draw() -> void:
		draw_rect(Rect2(1, 1, 26, 30), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(0, 0, 26, 30), Color("efe2c4"))
		draw_rect(Rect2(0, 0, 26, 6), Color("b0403a"))
		draw_rect(Rect2(0, 0, 26, 1), Color("d06a5a"))
		draw_rect(Rect2(6, -1, 2, 3), Color("c9a24a"))
		draw_rect(Rect2(18, -1, 2, 3), Color("c9a24a"))
		for k in 7:
			draw_rect(Rect2(2 + k * 3, 24, 2, 2), Color("8a7a60") if k < 6 else Color("b0403a"))
		draw_arc(Vector2(21, 25), 2.5, 0, TAU, 10, Color("b0403a"), 1.0)
