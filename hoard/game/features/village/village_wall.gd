class_name VillageWall
extends Node2D
## The Emergency Fund as the town wall. Its height in stone courses is the fund against
## three months of expenses; a measuring post by the gate carries the month marks, and
## the fund is painted on the stone. Money leaving the fund knocks courses off (the
## bricks fall once, when the game next shows it); money in raises new courses.
## Position is the wall's base line; `spans` are [x_from, x_to] tile columns.

const COURSE_PX := 4
const BRICK := VillageArt.TOWN
## Night on old stone: the castle brick lit warm and low, not the pack's daylight blue.
const STONE_NIGHT := Color(0.6, 0.5, 0.52)
const TORCH_EVERY := 6  # tiles between torches on the wall face

var spans: Array = []
var post_x := 0  # tile column of the measuring post
var courses_total := 12

var _ghost := Node2D.new()
var _courses := Node2D.new()
var _top := Node2D.new()
var _fx := Node2D.new()
var _marks := Node2D.new()
var _fund_label: Label
var _target_label: Label
var _shown := -1
var _state: Dictionary = {}
var _glow: Array[Node] = []
var _rubble := Node2D.new()


func _ready() -> void:
	add_child(_ghost)
	_courses.modulate = STONE_NIGHT
	_top.modulate = STONE_NIGHT
	add_child(_courses)
	add_child(_top)
	_draw_ghost()
	add_child(_rubble)
	add_child(_marks)
	add_child(_fx)
	# The fund is carved into a stone plinth set at the wall's foot; the target under it.
	var mid := (float(spans[0][0]) + float(spans[0][1]) + 1.0) * 8.0 - 24.0
	_fund_label = VillageArt.paint(self, "", Vector2(mid, -21), VillageArt.BONE, 10)
	_fund_label.z_index = 2
	VillageArt.carry(_fund_label, "stone")
	_target_label = VillageArt.paint(self, "", Vector2(mid, -8), Color(VillageArt.BONE, 0.7), 10)
	_target_label.z_index = 2
	VillageArt.carry(_target_label, "carved")
	VillageArt.pool(self, Vector2(mid, -16), Color(VillageArt.WARM, 0.22), 60, 0.1)


func apply(wall: Dictionary) -> String:
	_state = wall
	VillageArt.number(_fund_label, VillageArt.dollars(int(wall.balance_cents)))
	VillageArt.number(_target_label, "of %s" % VillageArt.dollars(int(wall.target_cents)))
	courses_total = int(wall.courses_total)
	_draw_marks(wall)
	var now := int(wall.courses)
	var seen := int(wall.seen_courses)
	var change := ""
	if int(wall.fell_cents) > 0 and seen > now:
		change = "fell"
	elif int(wall.rose_cents) > 0 and now > seen:
		change = "rose"
	# On a change, stand the wall as it was last seen; play_change() then moves it.
	_build(now if change == "" else seen)
	_cap(bool(wall.full))
	return change


func _build(courses: int) -> void:
	for c in _courses.get_children():
		c.queue_free()
	for k in courses:
		_course(k, false)
	_shown = courses
	_place_top()
	_scatter_rubble()


func _course(k: int, animate: bool) -> Array[Sprite2D]:
	var made: Array[Sprite2D] = []
	var row := Node2D.new()
	row.name = "course_%d" % k
	_courses.add_child(row)
	for span: Array in spans:
		for x in range(int(span[0]), int(span[1]) + 1):
			var s := Sprite2D.new()
			# Tiny Town's castle brick, one 4 px band of it per course, offset every other course.
			var band := (k % 4) * COURSE_PX
			s.texture = VillageArt.tex(BRICK, Rect2(6 * 16, 10 * 16 + band, 16, COURSE_PX))
			s.centered = false
			s.position = Vector2(x * 16 + (8 if k % 2 else 0) - (8 if k % 2 and x == int(span[1]) else 0), -(k + 1) * COURSE_PX)
			s.region_enabled = false
			row.add_child(s)
			made.append(s)
			if animate:
				s.modulate.a = 0.0
				var tw := s.create_tween()
				tw.tween_interval((x - int(span[0])) * 0.008)
				tw.tween_property(s, "modulate:a", 1.0, 0.08)
	return made


## The wall as tall as three months of costs, drawn faintly so the gap shows.
func _draw_ghost() -> void:
	for span: Array in spans:
		for x in range(int(span[0]), int(span[1]) + 1):
			for k in courses_total:
				var s := Sprite2D.new()
				s.texture = VillageArt.tex(BRICK, Rect2(6 * 16, 10 * 16 + (k % 4) * COURSE_PX, 16, COURSE_PX))
				s.centered = false
				s.position = Vector2(x * 16, -(k + 1) * COURSE_PX)
				s.modulate = Color(VillageArt.VIOLET, 0.09)
				_ghost.add_child(s)
			var cap := Sprite2D.new()
			cap.texture = VillageArt.tex(BRICK, Rect2(4 * 16, 8 * 16, 16, 5))
			cap.centered = false
			cap.position = Vector2(x * 16, -courses_total * COURSE_PX - 5)
			cap.modulate = Color(VillageArt.VIOLET, 0.22)
			_ghost.add_child(cap)


func _place_top() -> void:
	for c in _top.get_children():
		c.queue_free()
	_glow.clear()
	var h := -_shown * COURSE_PX
	for span: Array in spans:
		for x in range(int(span[0]), int(span[1]) + 1):
			var s := Sprite2D.new()
			s.texture = VillageArt.tex(BRICK, Rect2(4 * 16, 8 * 16, 16, 5))
			s.centered = false
			s.position = Vector2(x * 16, h - 5)
			_top.add_child(s)
		# Crenellations along the top, a walkway line under them, torches on the face.
		var x0 := int(span[0]) * 16
		var x1 := (int(span[1]) + 1) * 16
		var merlons := BuildingSite.Painter.new()
		merlons.fn = func(c: Node2D) -> void:
			var mx := x0 + 1
			while mx + 5 <= x1:
				c.draw_rect(Rect2(mx - 1, h - 10, 7, 6), VillageArt.INK)
				c.draw_rect(Rect2(mx, h - 9, 5, 5), VillageArt.STONE_LIGHT)
				c.draw_rect(Rect2(mx, h - 9, 5, 1), Color(1, 1, 1, 0.55))
				c.draw_rect(Rect2(mx + 4, h - 8, 1, 4), VillageArt.STONE)
				mx += 9
			c.draw_rect(Rect2(x0, h - 1, x1 - x0, 1), Color(0, 0, 0, 0.45))
		_top.add_child(merlons)
		if _shown >= 3:
			for tx in range(int(span[0]) + 2, int(span[1]) - 1, TORCH_EVERY):
				_torch(Vector2(tx * 16 + 8, h + 7))


func _cap(full: bool) -> void:
	for g in _glow:
		if is_instance_valid(g):
			g.queue_free()
	_glow.clear()
	if not full:
		return
	var h := -_shown * COURSE_PX
	for span: Array in spans:
		for x in range(int(span[0]), int(span[1]) + 1, 2):
			_glow.append(VillageArt.glow(_top, Vector2(x * 16 + 16, h - 2), Color(VillageArt.BONE, 0.55), 46, 0.4))
		var w := (int(span[1]) - int(span[0]) + 1) * 16.0
		_glow.append(VillageArt.embers(_top, Vector2(int(span[0]) * 16 + w / 2.0, h - 4), VillageArt.BONE, w, 14, 14))


## A torch on the wall face: a bracket, a small flame, and a flickering pool on the stone and
## the road in front of it (lit, so the wall's own modulate doesn't dim it).
func _torch(at: Vector2) -> void:
	var t := Node2D.new()
	t.position = at
	t.modulate = Color(1.0 / STONE_NIGHT.r, 1.0 / STONE_NIGHT.g, 1.0 / STONE_NIGHT.b)
	_top.add_child(t)
	var bracket := BuildingSite.Painter.new()
	bracket.fn = func(c: Node2D) -> void:
		c.draw_rect(Rect2(-1, -3, 3, 5), VillageArt.INK)
		c.draw_rect(Rect2(0, -2, 1, 3), VillageArt.WOOD)
	t.add_child(bracket)
	var flame := VillageArt.anim(t, VillageArt.frames(VillageArt.FLAME, Vector2i(20, 30), 10, 12), Vector2(0, -6))
	flame.scale = Vector2(0.35, 0.35)
	flame.material = VillageArt.additive()
	VillageArt.pool(t, Vector2(0, -4), Color(1.0, 0.6, 0.3, 0.45), 40, 0.2)
	VillageArt.pool(t, Vector2(0, 22), Color(1.0, 0.6, 0.3, 0.22), 90, 0.18)


## What's missing from the wall lies at its foot: rubble, more of it the lower the fund.
func _scatter_rubble() -> void:
	for c in _rubble.get_children():
		c.queue_free()
	var missing := clampi(courses_total - _shown, 0, courses_total)
	if missing == 0:
		return
	var i := 0
	for span: Array in spans:
		var w := (int(span[1]) - int(span[0]) + 1) * 16
		var n := int(missing * w / 90.0)
		for k in n:
			i += 1
			var b := Sprite2D.new()
			b.texture = VillageArt.tex(BRICK, Rect2(96 + (i % 3) * 5, 162, 6, 4))
			b.modulate = STONE_NIGHT
			b.position = Vector2(int(span[0]) * 16 + ((i * 53) % w), 2 + (i * 7) % 5)
			b.rotation = ((i * 37) % 7 - 3) * 0.15
			_rubble.add_child(b)


## The measuring post: three notches, one per month of expenses covered.
func _draw_marks(wall: Dictionary) -> void:
	for c in _marks.get_children():
		c.queue_free()
	var x := post_x * 16 + 8
	for y in 4:
		var post := Sprite2D.new()
		post.texture = VillageArt.tiles(VillageArt.TOWN, 11, 4 if y == 3 else 5)
		post.position = Vector2(x, -y * 16 - 8)
		_marks.add_child(post)
	for m: Dictionary in wall.marks:
		var y := -int(m.course) * COURSE_PX
		var reached := int(wall.courses) >= int(m.course)
		var notch := Sprite2D.new()
		notch.texture = VillageArt.tex(VillageArt.SPECKS, Rect2(16, 0, 8, 8))
		notch.position = Vector2(x, y)
		notch.modulate = VillageArt.BONE if reached else Color(VillageArt.VIOLET, 0.6)
		_marks.add_child(notch)
		# A notch cut across the post, its month in brass beside it.
		var cut := BuildingSite.Painter.new()
		cut.position = Vector2(x, y)
		cut.fn = func(c: Node2D) -> void:
			c.draw_rect(Rect2(-3, -1, 6, 2), VillageArt.INK)
			c.draw_rect(Rect2(-3, 1, 6, 1), Color(VillageArt.BRASS, 0.8 if reached else 0.3))
		_marks.add_child(cut)
		notch.visible = false
		var l := VillageArt.paint(_marks, str(int(m.months)), Vector2(x - 10, y), VillageArt.BRASS if reached else Color(VillageArt.BRASS, 0.45), 10)
		VillageArt.carry(l, "brass")


## Bricks fall (money left the fund) or courses rise (money came in), from what was last seen.
func play_change(village: Node, change: String) -> void:
	var now := int(_state.courses)
	if change == "fell":
		await _fall(village, now)
	elif change == "rose":
		await _rise(now)
	_cap(bool(_state.full))


func _fall(village: Node, to: int) -> void:
	VillageArt.sfx("themightyglider-breaking-rock/rock_break.ogg", 0.9, -6)
	for k in range(_shown - 1, to - 1, -1):
		var row := _courses.get_node_or_null("course_%d" % k)
		if row == null:
			continue
		for s: Node in row.get_children():
			var b := s as Sprite2D
			var tw := b.create_tween()
			var drop := randf_range(18, 34) + k * COURSE_PX
			tw.tween_interval(randf() * 0.15)
			tw.tween_property(b, "position", b.position + Vector2(randf_range(-10, 10), drop), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(b, "rotation", randf_range(-1.5, 1.5), 0.45)
			tw.tween_property(b, "modulate:a", 0.0, 0.35)
		VillageArt.sfx("rubberduck-80-rpg-sfx/stones_0%d.ogg" % (1 + k % 4), 1.0 - (_shown - k) * 0.04, -10)
		await VillageArt.wait(self, 0.09)
	for span: Array in spans:
		VillageArt.burst(_fx, Vector2((int(span[0]) + int(span[1])) * 8, -4), Color("8a7a6a"), 30, 70, 0.8)
	if village and village.has_method("shake"):
		village.shake(4.0)
	await VillageArt.wait(self, 0.8)
	_build(to)


func _rise(to: int) -> void:
	for k in range(_shown, to):
		_course(k, true)
		VillageArt.sfx("kenney-impact-sounds/Audio/impactPlate_light_00%d.ogg" % (k % 5), 0.85 + k * 0.05, -10)
		_shown = k + 1
		_place_top()
		await VillageArt.wait(self, 0.07)


func poke() -> void:
	for i in _marks.get_child_count():
		var n := _marks.get_child(i) as CanvasItem
		if n is Label:
			VillageArt.squash(n, Vector2(1.3, 1.3), 0.3)
	VillageArt.squash(_fund_label, Vector2(1.25, 1.25), 0.3)
	VillageArt.sfx("kenney-impact-sounds/Audio/impactPlate_medium_00%d.ogg" % (randi() % 3), randf_range(0.9, 1.1), -10)
