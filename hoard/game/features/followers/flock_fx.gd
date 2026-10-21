class_name FlockFx
## Juice for the flock in world (or overlay) space: bursts, rising specks, floating numbers,
## rings, motes and hit stop. Every helper adds short-lived nodes that free themselves.


## A one-shot spray of square pixels.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 14, speed := 60.0, life := 0.5, gravity := 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.position = pos
	p.z_index = 60
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## SPD specks (hearts, notes, stars) that pop up and drift away.
static func specks(parent: Node, pos: Vector2, index: int, count := 3, spread := 10.0, tint := Color.WHITE) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	for i in count:
		var s := Sprite2D.new()
		s.texture = FollowerArt.speck(index)
		s.modulate = tint
		s.position = pos + Vector2(randf_range(-spread, spread), randf_range(-3, 3))
		s.scale = Vector2.ZERO
		s.z_index = 70
		parent.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(s, "scale", Vector2.ONE * 1.25, 0.09)
		tw.tween_property(s, "scale", Vector2.ONE, 0.09)
		tw.parallel().tween_property(s, "position:y", s.position.y - 14.0 - randf() * 8.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", 0.0, 0.25)
		tw.tween_callback(s.queue_free)


## A number or word that pops up and drifts away, in a pack font with an ink outline.
static func float_text(parent: Node, pos: Vector2, text: String, color: Color, size := 10, font := FollowerArt.FONT_NUMBERS) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 80
	parent.add_child(holder)
	var l := FollowerArt.label(text, font, size, color)
	l.size = Vector2(120, 16)
	l.position = Vector2(-60, -8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(l)
	holder.scale = Vector2(0.4, 0.4)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(holder, "position:y", pos.y - 18.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 0.0, 0.3)
	tw.tween_callback(holder.queue_free)


## An expanding ring (Ninja Adventure's white circle), tinted.
static func ring(parent: Node, pos: Vector2, color: Color, radius := 24.0, seconds := 0.4) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Sprite2D.new()
	s.texture = FollowerArt.region(FollowerArt.RING, Rect2(96, 0, 32, 32))
	s.modulate = color
	s.position = pos
	s.z_index = 55
	s.scale = Vector2.ONE * 0.2
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * (radius / 16.0), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(s, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


## Bone-white motes: the only way real dollars are drawn. They arc from `from` to `to`,
## each a bright speck with a soft halo.
static func motes(parent: Node, from: Vector2, to: Vector2, count := 16, seconds := 0.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	for i in count:
		var m := Sprite2D.new()
		m.texture = FollowerArt.speck(FollowerArt.SPECK_SPARKLE)
		m.modulate = Palette.CREAM
		m.scale = Vector2.ONE * randf_range(0.8, 1.3)
		m.z_index = 75
		var halo := FollowerArt.glow(Color(Palette.CREAM, 0.45), 6.0, FollowerArt.SOFT)
		halo.show_behind_parent = true
		m.add_child(halo)
		var start := from + Vector2(randf_range(-8, 8), randf_range(-6, 6))
		m.position = start
		parent.add_child(m)
		var mid := (start + to) / 2.0 + Vector2(randf_range(-50, 50), randf_range(-60, -10))
		var tw := m.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(m):
				m.position = start.lerp(mid, t).lerp(mid.lerp(to, t), t)
				m.rotation = t * TAU, 0.0, 1.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(m.queue_free)


## A wisp of cream spirit rising from a chanting follower (Ninja Adventure's Spirit FX).
static func spirit(parent: Node, pos: Vector2, color := Palette.CREAM) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Sprite2D.new()
	s.texture = FollowerArt.region(FollowerArt.SPIRIT, Rect2(0, 0, 32, 32))
	s.position = pos
	s.modulate = Color(color, 0.8)
	s.scale = Vector2.ONE * 0.5
	s.z_index = 65
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = add
	parent.add_child(s)
	var tw := s.create_tween()
	for f in 5:
		tw.tween_callback(func() -> void:
			if is_instance_valid(s):
				s.texture = FollowerArt.region(FollowerArt.SPIRIT, Rect2(f * 32, 0, 32, 32)))
		tw.tween_interval(0.1)
	tw.parallel().tween_property(s, "position:y", pos.y - 26.0, 0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)


## A puff of smoke (Ninja Adventure's circular smoke, 8 frames of 30x14).
static func puff(parent: Node, pos: Vector2, color := Palette.MUTED) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := Sprite2D.new()
	s.position = pos
	s.modulate = color
	s.z_index = 62
	parent.add_child(s)
	var tw := s.create_tween()
	for f in 8:
		tw.tween_callback(func() -> void:
			if is_instance_valid(s):
				s.texture = FollowerArt.region(FollowerArt.SMOKE, Rect2(f * 30, 0, 30, 14)))
		tw.tween_interval(0.05)
	tw.tween_callback(s.queue_free)


## Freeze the game for a beat. Real time, not game time.
static func hit_stop(tree: SceneTree, seconds := 0.08) -> void:
	Engine.time_scale = 0.05
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## Pop a node in from nothing with an overshoot.
static func pop_in(node: Node2D, to := Vector2.ONE, seconds := 0.22) -> void:
	node.scale = Vector2.ZERO
	var tw := node.create_tween()
	tw.tween_property(node, "scale", to * 1.2, seconds * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", to, seconds * 0.4)
