class_name VillageParcel
extends Node2D
## A parcel of the island that isn't the owner's yet: overgrowth, a violet haze, a rope line
## where it meets open land and a survey stake with a red flag. While it is closed the
## village keeps it off the walkable map (Village.is_walkable). When its land tier is built
## it opens: the stake pops, the ropes drop, the haze lifts, the overgrowth sinks into the
## ground in a puff of dust and the grass comes up. Nothing here is text.
## Position is the map origin, so everything inside is in map pixels. Y-sorted with the props.

const T := 16
## A wooden stake: the foot of Tiny Town's fence post (thin tip on top).
const POST := Rect2(180, 80, 8, 14)
const ROPE := Color("c9a46a")
const RAG := Color("d8453a")
## While closed the land beyond the rope is only shapes: lit near ink, never its own colors.
const SHAPE := Color(0.17, 0.14, 0.24)
const DECOR_LIT := Color(0.85, 0.85, 0.95)
const WILD_LIT := Color(0.62, 0.6, 0.72)
const FOG_TINT := Color(0.6, 0.5, 0.95)
## Overgrowth while closed, per kind of land: [sheet, col, row] single tiles.
const WILD := {
	"reach": [
		[VillageArt.NATURE, 0, 10], [VillageArt.NATURE, 1, 10], [VillageArt.NATURE, 2, 10],
		[VillageArt.NATURE, 6, 10], [VillageArt.NATURE, 8, 11], [VillageArt.NATURE, 9, 11],
		[VillageArt.NATURE, 4, 8], [VillageArt.NATURE, 5, 9], [VillageArt.TOWN, 5, 0],
	],
	"meadow": [
		[VillageArt.NATURE, 3, 10], [VillageArt.NATURE, 4, 10], [VillageArt.NATURE, 5, 10],
		[VillageArt.NATURE, 7, 10], [VillageArt.NATURE, 7, 11], [VillageArt.NATURE, 9, 10],
		[VillageArt.NATURE, 13, 11], [VillageArt.NATURE, 12, 11],
	],
	"cliffs": [
		[VillageArt.NATURE, 17, 17], [VillageArt.NATURE, 18, 17], [VillageArt.NATURE, 19, 17],
		[VillageArt.NATURE, 12, 11], [VillageArt.NATURE, 13, 11], [VillageArt.NATURE, 5, 9],
		[VillageArt.NATURE, 4, 9],
	],
}
## What stands on the land either way (and blocks it): [sheet, col, row, w, h, tile x, tile y]
## with the tile relative to the parcel's top-left; the sprite's feet are that tile's bottom.
const DECOR := {
	"reach": [
		[VillageArt.NATURE, 6, 8, 2, 2, 16, 2], [VillageArt.NATURE, 6, 8, 2, 2, 15, 9],
		[VillageArt.TOWN, 4, 1, 1, 2, 1, 1], [VillageArt.NATURE, 0, 8, 2, 2, 3, 9],
	],
	"meadow": [
		[VillageArt.NATURE, 6, 8, 2, 2, 15, 2], [VillageArt.TOWN, 3, 1, 1, 2, 9, 1],
		[VillageArt.TOWN, 4, 1, 1, 2, 16, 6],
	],
	"cliffs": [
		[VillageArt.NATURE, 17, 14, 4, 3, 14, 4], [VillageArt.NATURE, 21, 14, 2, 3, 8, 3],
		[VillageArt.NATURE, 15, 16, 2, 2, 4, 6], [VillageArt.NATURE, 15, 14, 2, 2, 11, 7],
		[VillageArt.NATURE, 4, 0, 2, 2, 17, 1],
	],
}
## Ground that shows once the parcel opens: how often a tile is flowers (1 in n).
const BLOOM := {"reach": 12, "meadow": 7, "cliffs": 23}
## What grows on the land once it's tended (doesn't block): [sheet, col, row], sparse.
const BITS := {
	"reach": [[VillageArt.NATURE, 1, 10], [VillageArt.NATURE, 2, 10], [VillageArt.NATURE, 6, 11], [VillageArt.NATURE, 4, 8]],
	"meadow": [[VillageArt.NATURE, 0, 11], [VillageArt.NATURE, 1, 11], [VillageArt.NATURE, 3, 11], [VillageArt.NATURE, 6, 11], [VillageArt.NATURE, 2, 11]],
	"cliffs": [[VillageArt.NATURE, 17, 17], [VillageArt.NATURE, 18, 17], [VillageArt.NATURE, 19, 17], [VillageArt.NATURE, 2, 11]],
}

var parcel_id := ""
var rect := Rect2i()
var land := "reach"
var stake_tile := Vector2i.ZERO
var is_open := false

var _wild := Node2D.new()
var _bits := Node2D.new()
var _ropes := Node2D.new()
var _haze := Node2D.new()
var _stake := Node2D.new()
var _decor_tiles: Array[Rect2i] = []
var _rope_key := ""
var _decor: Array[Sprite2D] = []
var _fogs: Array[Sprite2D] = []
var _rope_mist := Node2D.new()
var _fog_t := 0.0


func _ready() -> void:
	y_sort_enabled = true
	for n: Node2D in [_wild, _bits, _ropes, _stake]:
		n.y_sort_enabled = true
		add_child(n)
	_haze.z_index = 3
	add_child(_haze)
	_rope_mist.z_index = 3
	add_child(_rope_mist)
	_build_decor()
	_build_wild()
	_build_bits()
	_build_stake()
	_build_haze()
	_build_eyes()


func _process(delta: float) -> void:
	# Two layers of fog drift over the land in opposite directions.
	if not _haze.visible:
		return
	_fog_t += delta
	for i in _fogs.size():
		# The sheet tiles, so the fog just scrolls on, a whole texel at a time.
		var f := _fogs[i]
		var o: Vector2 = f.get_meta("origin")
		var speed := 2.0 if i == 0 else -1.4
		f.region_rect.position = Vector2(fposmod(o.x + floorf(_fog_t * speed), 320.0), o.y + floorf(sin(_fog_t * 0.05 + i) * 3.0))


## The parcel in pixels.
func px_rect() -> Rect2:
	return Rect2(Vector2(rect.position * T), Vector2(rect.size * T))


func center() -> Vector2:
	return px_rect().get_center()


## Tiles that stay blocked once open (trees and rocks that stand on the land).
func decor_tiles() -> Array[Rect2i]:
	return _decor_tiles


## Open or close at once, with no show (the village was just loaded).
func set_open(open: bool) -> void:
	is_open = open
	_bits.visible = open
	for c in _bits.get_children():
		(c as Node2D).modulate.a = 1.0
		(c as Node2D).scale = Vector2.ONE
	_wild.visible = not open
	_ropes.visible = not open
	_stake.visible = not open
	_haze.visible = not open
	for c in _wild.get_children():
		(c as Node2D).scale = Vector2.ONE
		(c as CanvasItem).modulate.a = 1.0
	_haze.modulate.a = 1.0
	_haze.position = Vector2.ZERO
	_stake.modulate.a = 1.0
	_stake.position = Vector2.ZERO
	_rope_mist.visible = not open
	_rope_mist.modulate.a = 1.0
	for d in _decor:
		d.modulate = DECOR_LIT if open else SHAPE
	for c in _wild.get_children():
		(c as CanvasItem).modulate = Color(WILD_LIT, 1.0) if open else Color(SHAPE, 1.0)


## The rope runs along these boundary lines (pixel segments) where the parcel meets open land.
func set_ropes(segments: Array) -> void:
	_ropes.visible = not is_open
	var key := str(segments)
	if key == _rope_key:
		return
	_rope_key = key
	for c in _ropes.get_children():
		c.queue_free()
	for c in _rope_mist.get_children():
		c.queue_free()
	for seg: Array in segments:
		_rope(seg[0], seg[1])
		_mist_along(seg[0], seg[1])


## The reveal: stake pops, ropes drop, haze lifts, dust, grass comes up. The village pans here
## first; `ground` is a Callable(cell: Vector2i, open: bool) that repaints one ground tile.
func play_open(ground: Callable) -> void:
	is_open = true
	Sfx.duck(-8.0, 1.6)
	var c := center()
	# The survey stake comes out of the ground.
	VillageArt.sfx("ninja-adventure/Audio/Sounds/Whoosh & Slash/Slash.ogg", 1.3, -10)
	var pop := _stake.create_tween()
	pop.tween_property(_stake, "position:y", -10.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_stake, "position:y", 20.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pop.parallel().tween_property(_stake, "modulate:a", 0.0, 0.35)
	await VillageArt.wait(self, 0.3)
	# The rope lines drop, post by post.
	var posts := _ropes.get_children()
	for i in posts.size():
		var p := posts[i] as Node2D
		var tw := p.create_tween()
		tw.tween_interval(i * 0.03)
		if p is Line2D:
			tw.tween_property(p, "position:y", 6.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
		else:
			var side := -1.0 if i % 2 else 1.0
			tw.tween_property(p, "rotation", side * 1.4, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(p, "position:y", p.position.y + 3.0, 0.28)
			tw.tween_property(p, "modulate:a", 0.0, 0.3)
	VillageArt.sfx("ninja-adventure/Audio/Sounds/Hit & Impact/Hit2.ogg", 0.8, -14)
	await VillageArt.wait(self, 0.35)
	# The fog rolls back from the rope line outward and thins away.
	VillageArt.sfx("ninja-adventure/Audio/Sounds/Whoosh & Slash/Whoosh.ogg", 0.7, -8)
	var away := (center() - _rope_mid()).normalized() * 40.0
	var lift := _haze.create_tween()
	lift.tween_property(_haze, "position", away, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	lift.parallel().tween_property(_haze, "modulate:a", 0.0, 1.2)
	var mist := _rope_mist.create_tween()
	mist.tween_property(_rope_mist, "modulate:a", 0.0, 0.6)
	# Color floods in as a wave from the stake, a soft chime per step.
	var far0 := 1.0
	for d in _decor:
		far0 = maxf(far0, d.position.distance_to(Vector2(stake_tile * T)))
	for d in _decor:
		var k := d.position.distance_to(Vector2(stake_tile * T)) / far0
		var tw := d.create_tween()
		tw.tween_interval(k * 1.0)
		tw.tween_property(d, "modulate", DECOR_LIT, 0.35)
	for i in 5:
		_chime(i)
	# The overgrowth sinks in a wave from the stake outward, dust where it goes.
	var stake_px := Vector2(stake_tile * T)
	var far := 1.0
	for w in _wild.get_children():
		far = maxf(far, (w as Node2D).position.distance_to(stake_px))
	for w in _wild.get_children():
		var s := w as Node2D
		var d := s.position.distance_to(stake_px) / far
		var tw := s.create_tween()
		tw.tween_interval(d * 0.9)
		tw.tween_property(s, "scale", Vector2(1.3, 0.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "modulate:a", 0.0, 0.08)
	for i in 7:
		var at := stake_px.lerp(Vector2(rect.end.x * T - 24, rect.position.y * T + 24 + (i * 37) % int(rect.size.y * T - 40)), i / 6.0)
		_dust(at, i * 0.14)
	# The grass comes up column by column.
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			ground.call(Vector2i(x, y), true)
		if x % 2 == 0:
			await VillageArt.wait(self, 0.05)
	VillageArt.burst(self, c, Color(0.75, 0.9, 0.55), 40, 90, 1.0, 120)
	VillageArt.sfx("ninja-adventure/Audio/Sounds/Magic & Skill/Spirit.ogg", 1.0, -10)
	# What grows here pops up.
	_bits.visible = true
	for b in _bits.get_children():
		var s := b as Node2D
		s.modulate.a = 0.0
		s.scale = Vector2(0.4, 0.4)
		var tw := s.create_tween()
		tw.tween_interval(s.position.distance_to(stake_px) / far * 0.5)
		tw.tween_property(s, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(s, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await VillageArt.wait(self, 0.9)
	set_open(true)
	_rope_key = ""


func _chime(step: int) -> void:
	await VillageArt.wait(self, step * 0.22)
	VillageArt.sfx("kenney-impact-sounds/Audio/impactBell_heavy_00%d.ogg" % (step % 5), 1.8 + step * 0.12, -20)


func _rope_mid() -> Vector2:
	var posts := _ropes.get_children()
	if posts.is_empty():
		return Vector2(rect.position * T)
	var sum := Vector2.ZERO
	for p in posts:
		sum += (p as Node2D).position
	return sum / posts.size()


func _dust(at: Vector2, delay: float) -> void:
	await VillageArt.wait(self, delay)
	# A copy: the cached frames are shared with looping chimney smoke.
	var sf := VillageArt.frames(VillageArt.SMOKE, Vector2i(32, 32), 6, 12).duplicate() as SpriteFrames
	sf.set_animation_speed("default", 12.0)
	sf.set_animation_loop("default", false)
	var puff := VillageArt.anim(self, sf, at, false)
	puff.modulate = Color(0.85, 0.8, 0.75, 0.9)
	puff.scale = Vector2(1.4, 1.4)
	puff.z_index = 2
	puff.animation_finished.connect(puff.queue_free)


# --- building -----------------------------------------------------------------------------

func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ parcel_id.hash()) % 1000


func _build_decor() -> void:
	for d: Array in DECOR.get(land, []):
		var feet := Vector2((rect.position.x + d[5]) * T + d[3] * 8.0, (rect.position.y + d[6] + 1) * T)
		var s := VillageArt.sprite(self, VillageArt.tiles(d[0], d[1], d[2], d[3], d[4]), feet)
		s.modulate = SHAPE
		_decor.append(s)
		var w: int = d[3]
		var base := Vector2i(rect.position.x + int(d[5]), rect.position.y + int(d[6]))
		_decor_tiles.append(Rect2i(base.x, base.y, w, 1))


func _on_decor(cell: Vector2i) -> bool:
	for r in _decor_tiles:
		if r.grow(1).has_point(cell):
			return true
	return false


func _build_wild() -> void:
	var kinds: Array = WILD.get(land, WILD.reach)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var h := _hash(x, y)
			if h % 5 > 1 or _on_decor(Vector2i(x, y)):
				continue
			var k: Array = kinds[h % kinds.size()]
			var at := Vector2(x * T + 8 + (h % 7) - 3, (y + 1) * T - (h % 3))
			var s := VillageArt.sprite(_wild, VillageArt.tiles(k[0], k[1], k[2]), at, h % 2 == 0)
			s.modulate = SHAPE


func _build_bits() -> void:
	var kinds: Array = BITS.get(land, BITS.reach)
	for y in range(rect.position.y + 1, rect.end.y - 1):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			var h := _hash(x * 3 + 1, y * 5 + 2)
			if h % 13 != 0 or _on_decor(Vector2i(x, y)):
				continue
			var k: Array = kinds[h % kinds.size()]
			var s := VillageArt.sprite(_bits, VillageArt.tiles(k[0], k[1], k[2]), Vector2(x * T + 8, (y + 1) * T), h % 2 == 0)
			s.modulate = Color(0.75, 0.72, 0.85)
	_bits.visible = false


func _build_stake() -> void:
	var at := Vector2(stake_tile.x * T + 8, (stake_tile.y + 1) * T - 1)
	var flag := VillageArt.anim(_stake, VillageArt.frames(VillageArt.FLAG, Vector2i(16, 16), 4, 6), at + Vector2(0, -14))
	var post := VillageArt.sprite(_stake, VillageArt.tex(VillageArt.TOWN, POST), at)
	post.scale = Vector2(1.0, 1.2)
	VillageArt.glow(_stake, at + Vector2(0, -16), Color(RAG, 0.45), 26, 0.5)
	VillageArt.bob(flag, 0.5, 2.0)
	# A lantern swings from the stake.
	var hook := Node2D.new()
	hook.position = at + Vector2(-3, -14)
	_stake.add_child(hook)
	var lantern := VillageArt.sprite(hook, VillageArt.tiles(VillageArt.HOUSES, 29, 16), Vector2(0, 12))
	lantern.scale = Vector2(0.75, 0.75)
	VillageArt.pool(lantern, Vector2(0, -8), Color(1.0, 0.7, 0.4, 0.8), 18, 0.25)
	VillageArt.pool(_stake, at + Vector2(-3, -4), Color(1.0, 0.65, 0.35, 0.3), 70, 0.2)
	VillageArt.sway(hook, 0.22, 2.4)


## The land under a dim veil, with slow mist drifting over it (kept inside the parcel).
func _build_haze() -> void:
	var r := px_rect()
	var veil := Polygon2D.new()
	veil.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	veil.color = Color(0.04, 0.02, 0.09, 0.5)
	_haze.add_child(veil)
	# Two layers of the pack's fog at whole-number scales (2x and 3x, never stretched to fit),
	# tiling and scrolling against each other. Faint: the silhouettes, the eyes and the
	# stake's lantern do the work.
	for i in 2:
		var k := 2.0 if i == 0 else 3.0
		var f := Sprite2D.new()
		f.texture = VillageArt.sheet(VillageArt.FOG)
		f.centered = false
		f.region_enabled = true
		f.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		f.region_rect = Rect2(Vector2(0, 0) if i == 0 else Vector2(137, 61), (r.size / k).ceil())
		f.scale = Vector2(k, k)
		f.position = r.position
		f.material = VillageArt.additive()
		f.modulate = Color(FOG_TINT, 0.06 if i == 0 else 0.05)
		f.set_meta("origin", f.region_rect.position)
		_haze.add_child(f)
		_fogs.append(f)
	var n := maxi(3, int(r.size.x * r.size.y / 9000.0))
	for i in n:
		var h := _hash(i * 7, i * 13 + 5)
		var size := minf(r.size.x, r.size.y) * (0.55 + (h % 30) / 100.0)
		var inner := r.grow(-size * 0.4)
		var at := inner.position + Vector2((h % 97) / 97.0 * inner.size.x, ((h / 97) % 89) / 89.0 * inner.size.y)
		var mist := VillageArt.glow(_haze, at, Color(0.62, 0.52, 0.92, 0.16), size)
		mist.scale.y *= 0.55
		var drift := mist.create_tween().set_loops()
		var dx := (12.0 + h % 10) * (1.0 if i % 2 else -1.0)
		drift.tween_property(mist, "position:x", at.x + dx, 5.0 + (h % 5)).set_trans(Tween.TRANS_SINE)
		drift.tween_property(mist, "position:x", at.x - dx, 5.0 + (h % 5)).set_trans(Tween.TRANS_SINE)


## Fog banks up thick along the rope line.
func _mist_along(a: Vector2, b: Vector2) -> void:
	var n := maxi(2, int(a.distance_to(b) / 40.0))
	var inward := (center() - a.lerp(b, 0.5)).normalized()
	var horizontal := absf(b.x - a.x) > absf(b.y - a.y)
	for i in n + 1:
		var at := a.lerp(b, float(i) / n) + inward * 10.0
		var m := VillageArt.glow(_rope_mist, at, Color(FOG_TINT, 0.2), 64, 0.3)
		if horizontal:
			m.scale.y *= 0.45
		else:
			m.scale.x *= 0.45
		var tw := m.create_tween().set_loops()
		var dx := Vector2(6, 0) if horizontal else Vector2(0, 6)
		tw.tween_property(m, "position", at + dx, 3.0 + i % 3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position", at - dx, 3.0 + i % 3).set_trans(Tween.TRANS_SINE)


## Pairs of eyes in the dark beyond the rope: they open, blink, and are gone.
func _build_eyes() -> void:
	for i in 3:
		var eyes := BuildingSite.Painter.new()
		eyes.material = VillageArt.additive()
		eyes.z_index = 4
		eyes.fn = func(c: Node2D) -> void:
			c.draw_rect(Rect2(-2, 0, 1, 1), Color(1.0, 0.85, 0.5))
			c.draw_rect(Rect2(2, 0, 1, 1), Color(1.0, 0.85, 0.5))
		eyes.modulate.a = 0.0
		_haze.add_child(eyes)
		_blink(eyes, i * 2.3)


func _blink(eyes: Node2D, delay: float) -> void:
	await VillageArt.wait(self, delay + randf_range(1.0, 4.0))
	while is_inside_tree() and not is_open:
		var r := px_rect().grow(-24)
		eyes.position = (r.position + Vector2(randf() * r.size.x, randf() * r.size.y)).round()
		var tw := eyes.create_tween()
		tw.tween_property(eyes, "modulate:a", 0.9, 0.4)
		tw.tween_interval(randf_range(1.2, 2.4))
		tw.tween_property(eyes, "scale:y", 0.0, 0.05)
		tw.tween_property(eyes, "scale:y", 1.0, 0.06)
		tw.tween_interval(randf_range(0.6, 1.4))
		tw.tween_property(eyes, "modulate:a", 0.0, 0.25)
		await tw.finished
		await VillageArt.wait(self, randf_range(3.0, 8.0))


## Stakes every two tiles from a to b (pixels on a tile boundary), a sagging rope between their
## tips and a red rag on every other span.
func _rope(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var n := maxi(1, int(round(length / (T * 2.0))))
	var tips: Array[Vector2] = []
	for i in n + 1:
		var at := a.lerp(b, float(i) / n)
		var post := VillageArt.sprite(_ropes, VillageArt.tex(VillageArt.TOWN, POST), at)
		post.modulate = Color(0.85, 0.8, 0.85)
		tips.append(at + Vector2(0, -11))
		if i % 2 == 0:
			# A small lantern hangs on every other post.
			VillageArt.pool(post, Vector2(0, -13), Color(1.0, 0.68, 0.38, 0.75), 10, 0.3)
			VillageArt.pool(post, Vector2(0, -4), Color(1.0, 0.65, 0.35, 0.18), 44, 0.2)
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = ROPE
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.z_index = 1
	for i in tips.size() - 1:
		var p0 := tips[i]
		var p1 := tips[i + 1]
		var horizontal := absf(p1.x - p0.x) > absf(p1.y - p0.y)
		for k in 6:
			var t := k / 6.0
			var sag := sin(t * PI) * (3.0 if horizontal else 1.5)
			line.add_point(p0.lerp(p1, t) + (Vector2(0, sag) if horizontal else Vector2(sag, 0)))
		if i % 2 == 0:
			var rag := Polygon2D.new()
			var mid := p0.lerp(p1, 0.5) + Vector2(0, 3.0 if horizontal else 1.5)
			rag.polygon = PackedVector2Array([mid, mid + Vector2(2, 0), mid + Vector2(1, 4)])
			rag.color = RAG
			rag.z_index = 1
			_ropes.add_child(rag)
	line.add_point(tips[-1])
	_ropes.add_child(line)
