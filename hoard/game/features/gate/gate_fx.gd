class_name GateFx
## World-space juice for the gate: puffs, sparks, numbers, flashes, glows, hit-stop.
## The gate's camera never scrolls, so world space is screen space here.

const FONT := "res://art/packs/google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const PUFF := "res://art/packs/foozle-lucifer-effects/Effects/VFX/Destroy Effect.png"
const BLAST := "res://art/packs/ansimuz-explosions/Explosions pack/explosion-1-c/spritesheet.png"
const MONEY_GREEN := Color("8fbf7a")  # interest: a slow, muted green, never a rarity color
const ASH := Color("4a3f55")

static var _font: FontFile
static var _light: GradientTexture2D
static var _stops := 0


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


## A label in the pixel font with a dark outline, for numbers painted on things.
static func label(text: String, size := 10, color := Palette.CREAM, outline := 3) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A one-shot spray of square pixels.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 24, speed := 120.0, life := 0.6, gravity := 260.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.position = pos
	p.z_index = 60
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)


## The white puff from the packs, played once.
static func puff(parent: Node, pos: Vector2, scale := 1.0, z := 55) -> void:
	_play_sheet(parent, pos, load(PUFF), 6, 0.05, scale, z, null)


## A big ash-grey blast (the explosion art through a grey shader), for deaths.
static func blast(parent: Node, pos: Vector2, scale := 1.0) -> void:
	_play_sheet(parent, pos, load(BLAST), 10, 0.07, scale, 58, ash_material())


static func _play_sheet(parent: Node, pos: Vector2, tex: Texture2D, frames: int, step: float, scale: float, z: int, mat: Material) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = frames
	s.position = pos
	s.scale = Vector2(scale, scale)
	s.z_index = z
	if mat:
		s.material = mat
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "frame", frames - 1, step * frames).from(0)
	tw.tween_callback(s.queue_free)


static func ash_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 ash : source_color = vec4(0.82, 0.78, 0.86, 1.0);
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = vec3(g) * ash.rgb;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## The boss sprite's material: white flash, a color wash (heal), and a pixel dissolve (death).
static func boss_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, wash.rgb, wash.a);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	if (dissolve > 0.0) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
		float n = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453);
		if (n < dissolve) {
			discard;
		}
	}
	COLOR = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A soft additive light, for pools of light and glows.
static func glow(color: Color, radius: float, z := -5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = light_texture()
	s.modulate = color
	s.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.z_index = z
	return s


static func light_texture() -> GradientTexture2D:
	if _light == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.add_point(0.7, Color(1, 1, 1, 0.12))
		_light = GradientTexture2D.new()
		_light.gradient = g
		_light.fill = GradientTexture2D.FILL_RADIAL
		_light.fill_from = Vector2(0.5, 0.5)
		_light.fill_to = Vector2(1.0, 0.5)
		_light.width = 64
		_light.height = 64
	return _light


## Paints a sprite one flat color, keeping its shape: silhouettes and outlines.
static func solid_material(color: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(fill.rgb, COLOR.a * fill.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("fill", color)
	return m


## Real money is bone white: any sprite through this reads as bone, light to shadow.
static func bone_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 light : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 shade : source_color = vec4(0.55, 0.47, 0.40, 1.0);
void fragment() {
	float g = clamp((dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)) - 0.25) / 0.6, 0.0, 1.0);
	COLOR.rgb = mix(shade.rgb, light.rgb, g);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A round pixel disc, for the moon.
static func disc(radius: int, color: Color) -> ImageTexture:
	var d := radius * 2 + 1
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var v := Vector2(x - radius, y - radius)
			if v.length() <= radius + 0.3:
				var shade := 1.0 - 0.18 * clampf((v.x + v.y) / (radius * 2.0) + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	return ImageTexture.create_from_image(img)


## A number that pops from 1.6 to 1.0, rises 14 px over 0.7 s, and fades at the end.
static func float_number(parent: Node, pos: Vector2, text: String, color: Color, size := 16, rise := 14.0, seconds := 0.7) -> Label:
	var l := label(text, size, color, 4)
	l.size = Vector2(120, size + 4)
	l.position = pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.6, 1.6)
	l.z_index = 80
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - rise, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(maxf(0.0, seconds - 0.25) + 0.35)
	tw.tween_callback(l.queue_free)
	return l


## A flash over the whole view (a rect a little bigger than the screen, above everything).
static func flash(parent: Node, color: Color, alpha := 0.6, seconds := 0.12) -> void:
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.position = Vector2(-40, -40)
	r.size = Vector2(560, 360)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 120
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, seconds)
	tw.tween_callback(r.queue_free)


## Freeze the game for a beat. Real time, not game time. Overlapping stops don't fight.
static func hit_stop(tree: SceneTree, seconds := 0.08) -> void:
	_stops += 1
	Engine.time_scale = 0.03
	await tree.create_timer(seconds, true, false, true).timeout
	_stops -= 1
	if _stops <= 0:
		_stops = 0
		Engine.time_scale = 1.0


## Hit-stop by the size of the payment (the Vampire Survivors table).
static func stop_for(amount_cents: int) -> float:
	if amount_cents < 2500:
		return 0.06
	if amount_cents < 10000:
		return 0.08
	return 0.12


## The minor pentatonic over two octaves, for rising motes and chants.
static func pent(step: int) -> float:
	const SCALE := [0, 3, 5, 7, 10]
	var s: int = SCALE[step % 5] + 12 * ((step / 5) % 2)
	return pow(2.0, s / 12.0)
