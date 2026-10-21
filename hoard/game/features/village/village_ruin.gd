class_name VillageRuin
extends Node2D
## A ruined building and its offering tablet (Stardew's bundles, with no scroll and no
## words). Each socket shows the dark shape of what fills it; real behavior fills it,
## and a full tablet restores the building for good. Position is the building's feet.

const SOCKET_GAP := 12.0
const RESTORED_BEAT := 2.6

var ruin_id := ""
var ruined_art: Array = []  # [sheet, col, row, w, h]
var restored_art: Array = []
var tablet_at := Vector2(40, 0)  # from the building's feet

var _building := Sprite2D.new()
var _extras := Node2D.new()
var _tablet := Node2D.new()
var _stone: Sprite2D
var _sockets := Node2D.new()
var _socket_nodes: Array[Dictionary] = []  # {icon, hole, glow, filled, new}
var _state: Dictionary = {}
var _restored_shown := false
var _breath: Tween


func _ready() -> void:
	add_child(_building)
	add_child(_extras)
	_tablet.position = tablet_at
	add_child(_tablet)
	_stone = VillageArt.sprite(_tablet, VillageArt.tex(VillageArt.DCSS + "altars/altar_old.png", Rect2(0, 0, 32, 32)), Vector2(0, 3))
	VillageArt.glow(_tablet, Vector2(0, -20), Color(VillageArt.VIOLET, 0.25), 70, 0.3)
	for x in [-11, 11]:
		VillageArt.glow(_tablet, Vector2(x, -24), Color(1.0, 0.7, 0.4, 0.8), 14, 0.5)
	_sockets.position = Vector2(0, -40)
	_tablet.add_child(_sockets)
	_breath = VillageArt.breathe(_sockets, 0.02, 2.4)


## Returns what needs playing: "restore", "fill" or "".
func apply(ruin: Dictionary) -> String:
	_state = ruin
	var restored: bool = ruin.restored
	var fresh: bool = ruin.get("fresh", false)
	_build_sockets(ruin)
	var any_new := _socket_nodes.any(func(s: Dictionary) -> bool: return s.new)
	if restored and not fresh:
		_show_building(true)
	elif not _restored_shown:
		_show_building(false)
	if restored and fresh:
		return "restore"
	return "fill" if any_new else ""


func _show_building(restored: bool) -> void:
	var art := restored_art if restored else ruined_art
	_building.texture = VillageArt.tiles(art[0], art[1], art[2], art[3], art[4])
	_building.offset = Vector2(0, -art[4] * 8.0)
	_restored_shown = restored
	for c in _extras.get_children():
		c.queue_free()
	if restored:
		_dress_restored()
	else:
		_building.modulate = Color(0.85, 0.85, 0.9)
		VillageArt.glow(_extras, Vector2(0, -art[4] * 8.0), Color(VillageArt.SICK, 0.12), art[3] * 22.0, 0.5)
		# Something lives in the ruin: two eyes in the doorway that blink now and then.
		var eyes := Node2D.new()
		eyes.position = Vector2(0, -9)
		_extras.add_child(eyes)
		for ex in [-3, 3]:
			var e := Sprite2D.new()
			e.texture = VillageArt.tex(VillageArt.SPECKS, Rect2(16, 0, 8, 8))
			e.position = Vector2(ex, 0)
			e.scale = Vector2(0.35, 0.35)
			e.modulate = VillageArt.SICK
			eyes.add_child(e)
		var blink := eyes.create_tween().set_loops()
		blink.tween_interval(randf_range(1.5, 4.0))
		blink.tween_property(eyes, "scale:y", 0.1, 0.06)
		blink.tween_property(eyes, "scale:y", 1.0, 0.08)
		blink.tween_property(eyes, "position:x", randf_range(-3, 3), 0.4)


func _dress_restored() -> void:
	_building.modulate = Color.WHITE
	var art := restored_art
	var h: float = art[4] * 16.0
	VillageArt.glow(_extras, Vector2(0, -h * 0.4), Color(1.0, 0.72, 0.4, 0.7), art[3] * 26.0, 0.3)
	VillageArt.embers(_extras, Vector2(0, -h + 4), Color(1.0, 0.8, 0.5, 0.8), art[3] * 12.0, 5, 10)
	match ruin_id:
		"ossuary":
			_trophies()
		"bell_tower":
			var bell := Sprite2D.new()
			bell.texture = VillageArt.sheet(VillageArt.PACKS + "publicvoid-slot-symbols/bell.png")
			bell.position = Vector2(0, -h + 22)
			bell.scale = Vector2(0.5, 0.5)
			bell.offset = Vector2(0, 12)
			_extras.add_child(bell)
			VillageArt.glow(_extras, bell.position + Vector2(0, 6), Color(VillageArt.BONE, 0.5), 30, 0.4)
			var swing := bell.create_tween().set_loops()
			swing.tween_property(bell, "rotation", 0.18, 1.1).set_trans(Tween.TRANS_SINE)
			swing.tween_property(bell, "rotation", -0.18, 1.1).set_trans(Tween.TRANS_SINE)
			if Game.state.get("village", {}).get("bell_rings", false):
				ring()
		"granary":
			# Favorite foods hang at the door, priced in coins (brass, never a $).
			for i in 3:
				var food := VillageArt.sprite(_extras, VillageArt.sheet(VillageArt.PACKS + "ninja-adventure/Items/Food/%s.png" % ["Onigiri", "Honey", "Sushi"][i]), Vector2(-14 + i * 14, 10))
				VillageArt.bob(food, 1.5, 1.4)
			var price := VillageArt.paint(_extras, "25", Vector2(0, 16), VillageArt.BRASS, 10)
			VillageArt.bob(price, 1.0, 2.0)


## The Ossuary's shelf: the rarest things the owner has won, each in its rarity's light.
func _trophies() -> void:
	var trophies: Array = Game.state.get("village", {}).get("trophies", [])
	for i in trophies.size():
		var t: Dictionary = trophies[i]
		var icon: Dictionary = t.get("icon", {})
		if icon.is_empty() or not ResourceLoader.exists(str(icon.get("sheet", ""))):
			continue
		var r: Array = icon.get("rect", [0, 0, 16, 16])
		var pos := Vector2(-30 + i * 12, 12)
		VillageArt.glow(_extras, pos + Vector2(0, -6), Color(Palette.RARITY.get(str(t.tier), Palette.COMMON), 0.8), 26, 0.4)
		var s := VillageArt.sprite(_extras, VillageArt.tex(str(icon.sheet), Rect2(r[0], r[1], r[2], r[3])), pos)
		s.scale = Vector2.ONE * 12.0 / maxf(1.0, float(r[2]))
		VillageArt.bob(s, 1.0, 1.8)


func _build_sockets(ruin: Dictionary) -> void:
	for c in _sockets.get_children():
		c.queue_free()
	_socket_nodes.clear()
	var all: Array = []
	for b: Dictionary in ruin.bundles:
		for s: Dictionary in b.sockets:
			all.append({"bundle": b, "socket": s})
	var width := (all.size() - 1) * SOCKET_GAP
	for i in all.size():
		var b: Dictionary = all[i].bundle
		var s: Dictionary = all[i].socket
		var pos := Vector2(-width / 2.0 + i * SOCKET_GAP, sin(i * 1.3) * 2.0)
		var hole := VillageArt.glow(_sockets, pos, Color(0, 0, 0, 0.85), 16)
		hole.material = null
		var glow := VillageArt.glow(_sockets, pos, Color(VillageArt.BONE, 0.0), 28)
		var icon_d: Dictionary = b.icon
		var r: Array = icon_d.rect
		var icon := Sprite2D.new()
		icon.texture = VillageArt.tex(str(icon_d.sheet), Rect2(r[0], r[1], r[2], r[3]))
		icon.position = pos
		icon.scale = Vector2(0.75, 0.75)
		_sockets.add_child(icon)
		var filled: bool = s.filled
		var is_new: bool = s.new
		var node := {"icon": icon, "hole": hole, "glow": glow, "filled": filled and not is_new, "new": is_new}
		_paint_socket(node)
		if node.filled:
			VillageArt.bob(icon, 1.0, 1.6, i * 0.3)
		elif int(b.need) - int(b.filled) == 1 and not is_new:
			# The last empty socket of a bundle pulls hardest: it pulses and glints.
			var pulse := icon.create_tween().set_loops()
			pulse.tween_property(icon, "scale", Vector2(0.86, 0.86), 0.4).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(icon, "scale", Vector2(0.75, 0.75), 0.4).set_trans(Tween.TRANS_SINE)
			glow.modulate = Color(VillageArt.VIOLET, 0.0)
			var shine := glow.create_tween().set_loops()
			shine.tween_property(glow, "modulate:a", 0.45, 0.4)
			shine.tween_property(glow, "modulate:a", 0.0, 0.4)
		_socket_nodes.append(node)


func _paint_socket(node: Dictionary) -> void:
	var icon: Sprite2D = node.icon
	var glow: Sprite2D = node.glow
	if node.filled:
		icon.modulate = Color.WHITE
		glow.modulate = Color(VillageArt.BONE, 0.55)
	else:
		icon.modulate = Color(0.32, 0.26, 0.4, 0.55)
		glow.modulate = Color(VillageArt.BONE, 0.0)


## New sockets fill one by one, each a little higher in pitch; a full bundle sings.
func play_fill(village: Node) -> void:
	var n := 0
	for node: Dictionary in _socket_nodes:
		if not node.new:
			continue
		var icon: Sprite2D = node.icon
		var land := icon.position
		icon.position = land + Vector2(0, -26)
		icon.modulate = Color(1, 1, 1, 0)
		var tw := icon.create_tween()
		tw.tween_property(icon, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(icon, "position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		node.filled = true
		node.new = false
		_paint_socket(node)
		VillageArt.squash(icon, Vector2(1.3, 0.7), 0.15)
		VillageArt.sfx("kenney-impact-sounds/Audio/impactWood_heavy_00%d.ogg" % (n % 5), pow(1.12246, n), -6)
		VillageArt.burst(_sockets, land, Color("8a7a6a"), 6, 30, 0.4)
		VillageArt.burst(_sockets, land, VillageArt.BONE, 10, 50, 0.6, 40)
		VillageArt.bob(icon, 1.0, 1.6)
		n += 1
		await VillageArt.wait(self, 0.18)
	if n > 0:
		VillageArt.sfx("owlishmedia-creepy-chanting/chant2.ogg", 1.0, -8)
		VillageArt.squash(_tablet, Vector2(1.15, 0.9), 0.3)
		if village and village.has_method("shake"):
			village.shake(1.5)


## The restoration: hammering speeds up, a flash, dust, the building swaps and its windows light.
func play_restore(village: Node) -> void:
	await play_fill(village)
	var art := ruined_art
	var top: float = -art[4] * 16.0
	for i in 10:
		VillageArt.sfx("kenney-impact-sounds/Audio/impactPlank_medium_00%d.ogg" % (i % 5), 0.9 + i * 0.05, -9)
		VillageArt.burst(_extras, Vector2(randf_range(-art[3] * 6.0, art[3] * 6.0), randf_range(top, 0)), Color("8a7a6a"), 6, 40, 0.5)
		await VillageArt.wait(self, 0.25 - i * 0.015)
	var flash := VillageArt.glow(self, Vector2(0, top / 2.0), Color(1, 1, 1, 1.0), 220)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.5)
	ft.tween_callback(flash.queue_free)
	VillageArt.burst(self, Vector2(0, -6), Color("8a7a6a"), 60, 90, 0.9)
	VillageArt.burst(self, Vector2(0, top / 2.0), VillageArt.BONE, 20, 120, 0.9, 40)
	VillageArt.sfx("shattered-pixel-dungeon/sounds/boss.mp3", 0.8, -4)
	_show_building(true)
	VillageArt.hit_stop(get_tree(), 0.1)
	if village and village.has_method("shake"):
		village.shake(4.0)
	_building.scale = Vector2.ONE
	var pop := _building.create_tween()
	pop.tween_property(_building, "scale", Vector2(1.0, 1.08), 0.14)
	pop.tween_property(_building, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("level_up")
	VillageArt.sfx("owlishmedia-creepy-chanting/chant7.ogg", 1.0, -6)
	await VillageArt.wait(self, RESTORED_BEAT * 0.4)


## The bell tower rings on paydays: rings of light pulse out from the top.
func ring() -> void:
	var art := restored_art
	var top := Vector2(0, -art[4] * 16.0 + 10)
	for i in 3:
		var r := VillageArt.anim(_extras, VillageArt.frames(VillageArt.SPARK_RING, Vector2i(32, 32), 6, 10), top, false)
		r.modulate = Color(VillageArt.BONE, 0.9)
		r.scale = Vector2.ONE * (1.0 + i * 0.6)
		r.material = VillageArt.additive()
		r.create_tween().tween_interval(0.7).finished.connect(r.queue_free)
		VillageArt.sfx("kenney-impact-sounds/Audio/impactBell_heavy_00%d.ogg" % i, 1.0 - i * 0.06, -10)
		await VillageArt.wait(self, 0.45)


## A tap on the tablet: every socket hops, the empty ones flash their shapes.
func poke() -> void:
	VillageArt.squash(_tablet, Vector2(1.15, 0.88), 0.25)
	for i in _socket_nodes.size():
		var node: Dictionary = _socket_nodes[i]
		var icon: Sprite2D = node.icon
		var tw := icon.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(icon, "position:y", icon.position.y - 4, 0.08)
		tw.tween_property(icon, "position:y", icon.position.y, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if not node.filled:
			tw.parallel().tween_property(icon, "modulate", Color(0.7, 0.6, 0.85, 0.9), 0.1)
			tw.tween_property(icon, "modulate", Color(0.32, 0.26, 0.4, 0.55), 0.5)
		VillageArt.sfx("kenney-interface-sounds/Audio/pluck_00%d.ogg" % (1 + i % 2), pow(1.12246, i), -12)


func tablet_point() -> Vector2:
	return global_position + tablet_at + Vector2(0, -24)


func sockets_filled() -> int:
	return _socket_nodes.filter(func(s: Dictionary) -> bool: return s.filled).size()
