class_name CasinoFx
## Shared juice for the casino. Overlays live on the HUD layer (480x270), so these work in
## Control space. Owned by the reel builder; everyone else calls it.


## A one-shot spray of square pixels.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 24, speed := 120.0, life := 0.6) -> void:
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
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.position = pos
	p.z_index = 60
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


## A full-screen color flash on the overlay layer.
static func flash(parent: Control, color: Color, alpha := 0.55, seconds := 0.3) -> void:
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, seconds)
	tw.tween_callback(r.queue_free)


## Freeze the game for a beat (big moments only). Real time, not game time.
static func hit_stop(tree: SceneTree, seconds := 0.08) -> void:
	Engine.time_scale = 0.02
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## Slowly scale a Control up around its center, for reveals.
static func zoom(c: Control, to := 1.12, seconds := 0.8) -> Tween:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(to, to), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


## Bone-white motes fly from `from` to `to`, then "+$20 House Fund" floats up. Real money only.
static func money_landed(parent: Control, from: Vector2, to: Vector2, amount_cents: int, label: String) -> void:
	Sfx.play("cash")
	var count := clampi(amount_cents / 200, 6, 30)
	for i in count:
		var m := ColorRect.new()
		m.color = Palette.CREAM
		m.size = Vector2(2, 2)
		m.position = from + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(m)
		var mid := (from + to) / 2.0 + Vector2(randf_range(-40, 40), randf_range(-50, -10))
		var tw := m.create_tween()
		tw.tween_interval(i * 0.025)
		tw.tween_method(func(t: float) -> void:
			m.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.45)
		tw.tween_callback(m.queue_free)
	await parent.get_tree().create_timer(0.5).timeout
	Sfx.play("chant")
	float_text(parent, to + Vector2(0, -8), "+%s %s" % [Money.fmt(amount_cents), label], Palette.CREAM)


## A number or word that pops up and drifts away.
static func float_text(parent: Control, pos: Vector2, text: String, color: Color, size := 8) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos - Vector2(text.length() * 2.2, 0)
	l.scale = Vector2(0.5, 0.5)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", pos.y - 18, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


static func rarity_color(tier: String) -> Color:
	return Palette.RARITY.get(tier, Palette.CREAM)
