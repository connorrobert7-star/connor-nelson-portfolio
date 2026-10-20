class_name Village
extends Level
## The village. Crops, tavern, river drains and shrine are re-dressed from /state;
## every reaction state comes from the backend, this script only draws it.

const MAP: Array[String] = [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"T......................................T",
	"T..................................T...T",
	"TT..................................T..T",
	"T.....,................................T",
	"T..............,.......................T",
	"T..ssssssss...........,................T",
	"T..ssssssss.......................,....T",
	"T..ssssssss........................,...T",
	"T..ssssssss.......,.=.......,.=........T",
	"T......=...,........=.........=.,......T",
	"T.,...,=...,..,.....=..,......=........T",
	"T======================================T",
	"T....,........=...........=..,...,.....T",
	"T.......,.....=...........=............T",
	"T...............................,......T",
	"T.............................,......,TT",
	"T.,.......,..........................T.T",
	"TT.............,.......................T",
	"T.T..........,..,....,.........,.....,.T",
	"TT...................,................TT",
	"T,....,................................T",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]
const LEGEND := {".": 0, ",": 1, "=": 2, "~": 3, "s": 5, "T": 6}
const LOW_WATER := 4
const RIVER_EDGE_ROW := 4
const BANK_ROW := 5
const SPAWN := Vector2i(20, 17)

# Building footprints in tiles: x, y, w, h.
const HOUSE_PLOT := Rect2i(19, 10, 3, 3)
const TAVERN := Rect2i(29, 10, 4, 3)
const SHRINE := Rect2i(13, 19, 2, 3)
const SHOP := Rect2i(25, 19, 3, 3)
const BOARD := Rect2i(21, 15, 1, 1)
const FIELDS := Rect2i(3, 10, 8, 4)
const RIVER := Rect2i(0, 2, 40, 5)
const SHOP_DOOR := Vector2i(26, 21)
const TAVERN_DOOR := Vector2i(30, 12)

const CROP_FRAME := {"bumper": 0, "healthy": 1, "wilting": 2, "withered": 3}

var _shrine_sprite: Sprite2D


func build() -> void:
	map = MAP
	legend = LEGEND
	solid = "T~"
	place(preload("res://art/house_plot.png"), HOUSE_PLOT)
	place(preload("res://art/tavern.png"), TAVERN)
	place(preload("res://art/shop.png"), SHOP)
	place(preload("res://art/sign.png"), BOARD)
	_shrine_sprite = place(preload("res://art/shrine.png"), SHRINE, 2)
	for r: Rect2i in [TAVERN, SHOP, SHRINE, BOARD]:
		block(r)
	add_door(SHOP_DOOR, "shop", Room.ENTRANCE)
	add_door(TAVERN_DOOR, "tavern", Room.ENTRANCE)
	add_npc("farmer", Vector2i(11, 12), Vector2i(11, 13))
	add_npc("shrine_keeper", Vector2i(16, 21), Vector2i(16, 22))

	add_zone(FIELDS, _fields_text)
	add_zone(TAVERN, _tavern_text)
	add_zone(SHRINE, _shrine_text)
	add_zone(SHOP, _shop_text)
	add_zone(HOUSE_PLOT, _house_text, 0)
	add_zone(BOARD, _board_text, 2)
	add_zone(RIVER, _river_text)


func dress() -> void:
	_dress_crops()
	_dress_tavern()
	_dress_river()
	_shrine_sprite.frame = 1 if Game.state.shrine.state == "glowing" else 0


func _dress_crops() -> void:
	var main_frame: int = CROP_FRAME[Game.state.crops.state]
	# Wilting and withered fields keep a few plants one stage better, so it reads
	# as a field having a bad week rather than a dead one.
	for y in range(FIELDS.position.y, FIELDS.end.y):
		for x in range(FIELDS.position.x, FIELDS.end.x):
			var s := Sprite2D.new()
			s.texture = preload("res://art/crops.png")
			s.hframes = 4
			var better := main_frame >= 2 and (x * 7 + y * 13) % 4 == 0
			s.frame = main_frame - 1 if better else main_frame
			s.offset = Vector2(0, -8)
			s.position = Vector2(x * TILE + 8, (y + 1) * TILE)
			dynamic.add_child(s)


func _dress_tavern() -> void:
	if Game.state.tavern.state == "quiet":
		var coin := Sprite2D.new()
		coin.texture = preload("res://art/coin.png")
		coin.position = Vector2((TAVERN.position.x + 2.5) * TILE, TAVERN.end.y * TILE - 40)
		dynamic.add_child(coin)
		var tw := coin.create_tween().set_loops()
		tw.tween_property(coin, "position:y", coin.position.y - 4, 0.6)
		tw.tween_property(coin, "position:y", coin.position.y, 0.6)
	else:
		# Packed: the overflow sleeps it off outside.
		for i in 3:
			var s := Sprite2D.new()
			s.texture = preload("res://art/villager.png")
			s.hframes = 2
			s.frame = 1
			s.offset = Vector2(0, -8)
			s.position = Vector2((TAVERN.end.x) * TILE + 8, (TAVERN.position.y + 1 + i) * TILE)
			dynamic.add_child(s)


func _dress_river() -> void:
	var river: Dictionary = Game.state.drains
	var low: bool = river.river == "low"
	for x in MAP[0].length():
		set_tile(Vector2i(x, RIVER_EDGE_ROW), LOW_WATER if low else 3)
	var drains: Array = river.drains
	for i in drains.size():
		var d: Dictionary = drains[i]
		var x := 4 + i * 9
		var s := Sprite2D.new()
		s.texture = preload("res://art/drain.png")
		s.hframes = 2
		s.frame = 1 if d.charged_this_week else 0
		s.centered = false
		s.position = Vector2(x * TILE, BANK_ROW * TILE - 4)
		dynamic.add_child(s)
		var name := ("new: " if d.new else "") + str(d.merchant)
		dynamic.add_child(small_label(name, Vector2(x * TILE + 8, BANK_ROW * TILE + 10)))
		if d.charged_this_week:
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "modulate:a", 0.6, 0.5)
			tw.tween_property(s, "modulate:a", 1.0, 0.5)


# --- panel text --------------------------------------------------------------

func _fields_text() -> String:
	var crops: Dictionary = Game.state.crops
	var line: String = {
		"bumper": "Well under budget. Bumper harvest.",
		"healthy": "Under budget. The crops are healthy.",
		"wilting": "Over budget. The crops are wilting.",
		"withered": "Well over budget. The crops have withered.",
	}[crops.state]
	return "Fields\nGroceries for the week: %s of %s.\n%s" % [
		c(crops.spent_cents), c(crops.budget_cents), line
	]


func _tavern_text() -> String:
	var t: Dictionary = Game.state.tavern
	var line := (
		"Over budget. Packed, and the regulars will be lazy tomorrow."
		if t.state == "packed"
		else "Under budget. Quiet, and a few coins trickle in."
	)
	return "Tavern\nEating out for the week: %s of %s across %d visits.\n%s" % [
		c(t.spent_cents), c(t.budget_cents), int(t.visits), line
	]


func _river_text() -> String:
	var r: Dictionary = Game.state.drains
	var lines := PackedStringArray()
	lines.append("River")
	lines.append("Subscriptions in the last 30 days: %s of %s." % [c(r.monthly_cents), c(r.budget_cents)])
	lines.append("Over budget, so the river runs low." if r.river == "low" else "Under budget. The river is high.")
	for d: Dictionary in r.drains:
		var note := "new this week" if d.new else "last charged %s" % Main._day(d.last_charged)
		lines.append("  %s  %s  (%s)" % [d.merchant, c(d.amount_cents), note])
	return "\n".join(lines)


func _shrine_text() -> String:
	var saved := int(Game.state.shrine.saved_cents)
	if saved > 0:
		return "Shrine\nMoved to savings that week: %s.\nThe shrine is glowing." % Money.fmt(saved)
	return "Shrine\nNothing moved to savings that week.\nThe shrine is dim."


func _shop_text() -> String:
	var shop: Dictionary = Game.state.shop
	var can := int(shop.can_spend_cents)
	if can <= 0:
		return "Shop\nNothing to put in today. Come back next week."
	return "Shop\nYou can put in %s today, %s.\nWalk in to buy shares." % [
		c(can), hours(float(can) / float(shop.hourly_rate_cents))
	]


func _house_text() -> String:
	var h: Dictionary = Game.state.house
	return "House plot\n%s: %s.\nBuilding stages start in Phase 2." % [h.name, c(h.balance_cents)]


func _board_text() -> String:
	var w: Dictionary = Game.state.week
	var by: Dictionary = w.by_system
	var names: Array = by.keys().filter(func(k: String) -> bool: return by[k] > 0)
	names.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
	var lines := PackedStringArray()
	lines.append("Notice board: %s to %s" % [Main._day(Game.state.window.start), Main._day(Game.state.window.end)])
	var hourly := float(Game.state.shop.hourly_rate_cents)
	lines.append("In %s.  Out %s, or %s." % [c(w.in_cents), c(w.out_cents), hours(w.out_cents / hourly)])
	for n: String in names:
		lines.append("  %s  %s" % [Game.state.systems.get(n, n), c(by[n])])
	return "\n".join(lines)
