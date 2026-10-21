class_name GateFeature
extends HoardFeature
## The gate (Step 2): every debt is a boss outside the village. See gate_level.gd.

const X72 := "res://art/packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"


func id() -> String:
	return "gate"


func levels() -> Dictionary:
	return {"gate": GateLevel}


func plot_id() -> String:
	return "gate"


func door_level() -> String:
	return "gate"


## The gatehouse on the plot: a stretch of wall with the gate in the middle of its
## bottom row. The plot's door tile (from the village) leads in.
func build_village(village: Level, plot: Rect2i) -> void:
	var bottom := float(plot.end.y * Level.TILE)
	var cx := (plot.position.x + plot.size.x / 2.0) * Level.TILE
	for x in range(plot.position.x, plot.end.x):
		_piece(village, Rect2(32, 0, 16, 16), Vector2(x * Level.TILE, bottom - 32))
		_piece(village, Rect2(32, 16, 16, 16), Vector2(x * Level.TILE, bottom - 16))
	_piece(village, Rect2(32, 240, 32, 32), Vector2(cx - 16, bottom - 32))
	_piece(village, Rect2(16, 240, 16, 32), Vector2(cx - 32, bottom - 32))
	_piece(village, Rect2(64, 240, 16, 32), Vector2(cx + 16, bottom - 32))
	_piece(village, Rect2(32, 224, 32, 16), Vector2(cx - 16, bottom - 48))
	var blocked := Rect2i(plot.position.x, plot.end.y - 2, plot.size.x, 2)
	village.block(blocked)


## Every state change: the smallest boss looms over the wall, and its real balance is
## painted on the lamp above the gate.
func dress_village(village: Level, plot: Rect2i) -> void:
	var bosses: Array = Game.state.get("gate", {}).get("bosses", [])
	var alive := bosses.filter(func(b: Dictionary) -> bool: return not bool(b.defeated))
	var bottom := float(plot.end.y * Level.TILE)
	var cx := (plot.position.x + plot.size.x / 2.0) * Level.TILE
	if alive.is_empty():
		var calm := GateFx.glow(Color(Palette.CREAM, 0.45), 16, 0)
		calm.position = Vector2(cx, bottom - 56)
		village.dynamic.add_child(calm)
		return
	var b: Dictionary = alive[0]
	var look: Dictionary = b.look
	var r: Array = look.idle[0]
	var at := AtlasTexture.new()
	at.atlas = load(str(look.sheet))
	at.region = Rect2(r[0], r[1], r[2], r[3])
	var peek := Sprite2D.new()
	peek.texture = at
	peek.offset = Vector2(0, -float(r[3]) / 2.0)
	peek.position = Vector2(cx + 34, bottom - 22)
	peek.modulate = Color(0.75, 0.68, 0.8)
	village.dynamic.add_child(peek)
	var tw := peek.create_tween().set_loops()
	tw.tween_property(peek, "position:y", peek.position.y - 3, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(peek, "position:y", peek.position.y, 0.9).set_trans(Tween.TRANS_SINE)
	var lamp := GateFx.glow(Color(Palette.CREAM, 0.5), 18, 0)
	lamp.position = Vector2(cx, bottom - 56)
	village.dynamic.add_child(lamp)
	var number := GateFx.label(Money.fmt(int(b.hp_cents)), 10, Palette.CREAM, 3)
	number.size = Vector2(80, 12)
	number.position = Vector2(cx - 40, bottom - 64)
	number.z_index = 20
	village.dynamic.add_child(number)


func _piece(village: Level, region: Rect2, top_left: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(X72)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(0, -region.size.y)
	s.position = top_left + Vector2(0, region.size.y)
	village.props.add_child(s)
