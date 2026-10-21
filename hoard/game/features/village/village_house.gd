class_name VillageHouse
extends Node2D
## The House Fund as a house. Each stage is kitbashed from Kenney Tiny Town and
## Ninja Adventure tiles; the next stage stands as a ghost that fills up in rows
## to the true balance. Crossing a stage puts up scaffolding, drops it, and pops
## the new stage. Position is the bottom-left corner of the house's footprint.

signal tapped

const W := 4  # tiles wide
const ROWS_PX := 64  # tallest stage, in px
const T := VillageArt.TOWN
const H := VillageArt.HOUSES

## Parts per stage: [sheet, col, row, w, h, x tile, y tile from the bottom (0 = lowest row)].
const STAGES := {
	"plot": [
		[T, 11, 5, 1, 1, 0, 0], [T, 11, 5, 1, 1, 3, 0],
	],
	"foundation": [
		[T, 0, 10, 1, 1, 0, 0], [T, 1, 10, 1, 1, 1, 0], [T, 1, 10, 1, 1, 2, 0], [T, 2, 10, 1, 1, 3, 0],
	],
	"frame": [
		[T, 0, 10, 1, 1, 0, 0], [T, 1, 10, 1, 1, 1, 0], [T, 1, 10, 1, 1, 2, 0], [T, 2, 10, 1, 1, 3, 0],
		[H, 8, 4, 2, 2, 0, 0], [H, 8, 4, 2, 2, 2, 0],
	],
	"walls": [
		[T, 0, 7, 1, 1, 0, 0], [T, 2, 6, 1, 1, 1, 0], [T, 1, 6, 1, 1, 2, 0], [T, 0, 7, 1, 1, 3, 0],
		[T, 0, 6, 1, 1, 0, 1], [T, 1, 6, 1, 1, 1, 1], [T, 1, 6, 1, 1, 2, 1], [T, 3, 6, 1, 1, 3, 1],
	],
	"roof": [
		[T, 0, 7, 1, 1, 0, 0], [T, 2, 6, 1, 1, 1, 0], [T, 1, 6, 1, 1, 2, 0], [T, 0, 7, 1, 1, 3, 0],
		[T, 0, 6, 1, 1, 0, 1], [T, 1, 6, 1, 1, 1, 1], [T, 1, 6, 1, 1, 2, 1], [T, 3, 6, 1, 1, 3, 1],
		[T, 4, 5, 1, 1, 0, 2], [T, 5, 5, 1, 1, 1, 2], [T, 5, 5, 1, 1, 2, 2], [T, 6, 5, 1, 1, 3, 2],
		[T, 4, 4, 1, 1, 0, 3], [T, 5, 4, 1, 1, 1, 3], [T, 5, 4, 1, 1, 2, 3], [T, 6, 4, 1, 1, 3, 3],
	],
}

var _stage_root := Node2D.new()
var _ghost := Control.new()
var _ghost_fill := Node2D.new()
var _ghost_dim := Node2D.new()
var _fx := Node2D.new()
var _sign: Node2D = Node2D.new()
var _balance_label: Label
var _gap_label: Label
var _pips: Array[Sprite2D] = []
var _pile := Node2D.new()
var _shown_index := -1
var _state: Dictionary = {}


func _ready() -> void:
	add_child(_stage_root)
	add_child(_ghost_dim)
	_ghost.clip_contents = true
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	_ghost.add_child(_ghost_fill)
	add_child(_pile)
	add_child(_fx)
	# The sign post to the right, with the balance painted on it.
	_sign.position = Vector2(W * 16 + 14, 0)
	add_child(_sign)
	VillageArt.sprite(_sign, VillageArt.tiles(T, 11, 6), Vector2.ZERO)
	VillageArt.glow(_sign, Vector2(0, -20), Color(VillageArt.BONE, 0.35), 54, 0.3)
	_balance_label = VillageArt.paint(_sign, "", Vector2(0, -26), VillageArt.BONE, 10)
	for i in 7:
		var pip := Sprite2D.new()
		pip.texture = VillageArt.tex(VillageArt.SPECKS, Rect2(16, 0, 8, 8))
		pip.position = Vector2(-15 + i * 5, -18)
		pip.scale = Vector2(0.5, 0.5)
		_sign.add_child(pip)
		_pips.append(pip)
	_gap_label = VillageArt.paint(self, "", Vector2(W * 8, -ROWS_PX - 8), VillageArt.VIOLET, 10)
	VillageArt.bob(_gap_label, 1.5, 2.2)


## Draw the stage the backend says is built; returns true if a new stage needs its build beat.
func apply(house: Dictionary) -> bool:
	_state = house
	_balance_label.text = VillageArt.dollars(int(house.balance_cents))
	var index := int(house.index)
	for i in _pips.size():
		var on := i <= index
		_pips[i].modulate = VillageArt.BONE if on else Color(VillageArt.VIOLET, 0.35)
	var nxt: Variant = house.get("next")
	_gap_label.text = "" if nxt == null else VillageArt.dollars(int(nxt.to_go_cents))
	_pile_bricks(int(house.rows))
	var building: bool = house.get("building", false)
	var show := int(house.seen_index) if building else index
	if show != _shown_index:
		_draw_stage(_stage_root, _stage_id(show), 1.0)
		_shown_index = show
	_draw_ghost(index if not building else show)
	return building


func stage_count() -> int:
	return _state.get("stages", []).size()


func _stage_id(index: int) -> String:
	var stages: Array = _state.get("stages", [])
	return str(stages[clampi(index, 0, stages.size() - 1)].id) if not stages.is_empty() else "plot"


## The house at a stage: the parts of the highest kitbashed stage at or below it, plus dressing.
func _draw_stage(root: Node2D, stage: String, alpha: float) -> void:
	for c in root.get_children():
		c.queue_free()
	var base := stage
	if stage in ["interior", "finished"]:
		base = "roof"
	_dirt(root, alpha)
	for p: Array in STAGES[base]:
		var s := Sprite2D.new()
		s.texture = VillageArt.tiles(p[0], p[1], p[2], p[3], p[4])
		s.centered = false
		s.position = Vector2(p[5] * 16, -(p[6] + p[4]) * 16)
		s.modulate.a = alpha
		root.add_child(s)
	if alpha < 1.0:
		return
	if stage in ["walls", "roof", "interior", "finished"]:
		VillageArt.glow(root, Vector2(24, -10), Color(1.0, 0.7, 0.4, 0.55), 40, 0.4)
	if stage == "roof" or stage == "interior" or stage == "finished":
		var chimney := Sprite2D.new()
		chimney.texture = VillageArt.tiles(T, 7, 4)
		chimney.centered = false
		chimney.position = Vector2(2 * 16, -4 * 16)
		root.add_child(chimney)
	if stage == "interior" or stage == "finished":
		for x in [0, 3]:
			VillageArt.glow(root, Vector2(x * 16 + 8, -8), Color(1.0, 0.75, 0.4, 0.9), 34, 0.35)
		var smoke := VillageArt.anim(root, VillageArt.frames(VillageArt.SMOKE, Vector2i(32, 32), 6, 6), Vector2(2 * 16 + 8, -5 * 16 + 2))
		smoke.modulate = Color(1, 1, 1, 0.45)
	if stage == "finished":
		for x in range(-1, W + 1):
			var f := Sprite2D.new()
			f.texture = VillageArt.tiles(T, 9, 6)
			f.position = Vector2(x * 16 + 8, 6)
			root.add_child(f)
		var flag := VillageArt.anim(root, VillageArt.frames(VillageArt.FLAG, Vector2i(16, 16), 4, 6), Vector2(8, -4 * 16 - 8))
		flag.scale = Vector2(1, 1)
		VillageArt.glow(root, Vector2(W * 8, -32), Color(VillageArt.BONE, 0.35), 120, 0.25)
		VillageArt.embers(root, Vector2(W * 8, -60), Color(VillageArt.BONE, 0.8), 64, 8)


func _dirt(root: Node2D, alpha: float) -> void:
	if alpha < 1.0:
		return
	for y in 2:
		for x in W:
			var s := Sprite2D.new()
			var col := 0 if x == 0 else (2 if x == W - 1 else 1)
			s.texture = VillageArt.tiles(T, col, 2 + y)
			s.centered = false
			s.position = Vector2(x * 16, -16 + y * 16 - 8)
			s.z_index = -1
			s.modulate = Color(0.55, 0.45, 0.5)
			root.add_child(s)


## The next stage as a ghost: a dim outline, and the rows already paid for filled in.
func _draw_ghost(index: int) -> void:
	for c in _ghost_dim.get_children():
		c.queue_free()
	for c in _ghost_fill.get_children():
		c.queue_free()
	var stages: Array = _state.get("stages", [])
	if index + 1 >= stages.size():
		_ghost.visible = false
		return
	_ghost.visible = true
	var next_id := _stage_id(index + 1)
	var base := next_id if STAGES.has(next_id) else "roof"
	var cur := _stage_id(index)
	var cur_base := cur if STAGES.has(cur) else "roof"
	_draw_parts(_ghost_dim, base, Color(0.75, 0.6, 1.0, 0.32), STAGES[cur_base])
	_draw_parts(_ghost_fill, base, Color(VillageArt.BONE, 0.6), STAGES[cur_base])
	var fill := float(_state.get("fill", 0.0))
	var full := _stage_height(base)
	var built := minf(_stage_height(cur_base), full)
	var h := built + (full - built) * fill if full > built else full * fill
	_gap_label.position.y = -full - 14 - _gap_label.size.y / 2.0
	_ghost.position = Vector2(0, -h)
	_ghost.size = Vector2(W * 16, h)
	_ghost_fill.position = Vector2(0, h)


func _stage_height(stage: String) -> float:
	var top := 0
	for p: Array in STAGES[stage]:
		top = maxi(top, (p[6] + p[4]) * 16)
	return float(top)


## Draw a stage's parts; parts already standing (in `skip`) are left out.
func _draw_parts(root: Node2D, stage: String, tint: Color, skip: Array = []) -> void:
	for p: Array in STAGES[stage]:
		if skip.has(p):
			continue
		var s := Sprite2D.new()
		s.texture = VillageArt.tiles(p[0], p[1], p[2], p[3], p[4])
		s.centered = false
		s.position = Vector2(p[5] * 16, -(p[6] + p[4]) * 16)
		s.modulate = tint
		root.add_child(s)


## Bricks by the scaffold: one per eighth of the way to the next stage.
func _pile_bricks(rows: int) -> void:
	for c in _pile.get_children():
		c.queue_free()
	var count := clampi(rows / 3, 0, 10)
	for i in count:
		var b := Sprite2D.new()
		b.texture = VillageArt.tex(T, Rect2(96 + (i % 3) * 5, 162, 6, 4))
		b.position = Vector2(-10 + (i % 4) * 5 - (i / 4) * 2, -2 - (i / 4) * 4)
		_pile.add_child(b)


## The build beat: scaffold up, hammering, scaffold falls, the new stage pops.
func play_build(village: Node) -> void:
	var target := int(_state.index)
	var from := int(_state.seen_index)
	for stage_index in range(from + 1, target + 1):
		await _build_one(village, stage_index)
	_shown_index = target
	_draw_ghost(target)


func _build_one(village: Node, stage_index: int) -> void:
	var scaffold := Node2D.new()
	_fx.add_child(scaffold)
	for x in W:
		for y in 3:
			var s := Sprite2D.new()
			s.texture = VillageArt.tiles(T, 11, 4 + (y % 2))
			s.centered = false
			s.position = Vector2(x * 16, -(y + 1) * 16)
			s.modulate = Color(1, 1, 1, 0.0)
			scaffold.add_child(s)
			var tw := s.create_tween()
			tw.tween_interval((x + y * W) * 0.04)
			tw.tween_property(s, "modulate:a", 1.0, 0.1)
			VillageArt.sfx("kenney-impact-sounds/Audio/impactWood_light_00%d.ogg" % ((x + y) % 5), 1.0 + y * 0.08, -14)
	await VillageArt.wait(self, 0.55)
	for i in 6:
		VillageArt.sfx("kenney-impact-sounds/Audio/impactPlank_medium_00%d.ogg" % (i % 5), 0.9 + i * 0.07, -10)
		VillageArt.burst(_fx, Vector2(randf_range(4, W * 16 - 4), -randf_range(8, 40)), Color("8a7a6a"), 5, 30, 0.4)
		await VillageArt.wait(self, 0.12)
	# The scaffold falls and the new stage stands there.
	var fall := scaffold.create_tween()
	fall.tween_property(scaffold, "position:y", 30.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(scaffold, "modulate:a", 0.0, 0.25)
	fall.tween_callback(scaffold.queue_free)
	await fall.finished
	_draw_stage(_stage_root, _stage_id(stage_index), 1.0)
	VillageArt.sfx("kenney-impact-sounds/Audio/impactPunch_heavy_000.ogg", 0.8, -6)
	VillageArt.burst(_fx, Vector2(W * 8, -4), Color("8a7a6a"), 24, 70, 0.7)
	VillageArt.burst(_fx, Vector2(W * 8, -30), VillageArt.BONE, 16, 90, 0.8, 60)
	VillageArt.hit_stop(get_tree(), 0.08)
	if village and village.has_method("shake"):
		village.shake(3.0)
	_stage_root.scale = Vector2.ONE
	var pop := _stage_root.create_tween()
	_stage_root.position = Vector2.ZERO
	pop.tween_property(_stage_root, "scale", Vector2(1.0, 1.08), 0.12)
	pop.tween_property(_stage_root, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("level_up")
	VillageArt.sfx("owlishmedia-creepy-chanting/chant%d.ogg" % (3 + stage_index), 1.0, -8)
	await pop.finished
	await VillageArt.wait(self, 0.35)


func poke() -> void:
	VillageArt.squash(_stage_root, Vector2(1.06, 0.94))
	VillageArt.squash(_sign, Vector2(1.2, 0.85))
	VillageArt.sfx("kenney-impact-sounds/Audio/impactWood_medium_00%d.ogg" % (randi() % 5), randf_range(0.9, 1.1), -10)
	tapped.emit()
