class_name CasinoRoomChoir
extends Node2D
## The risers at the back, full of nameless cultists who chant in time with the belt:
## call and response, half the choir dipping on each beat. When a special shell is next they
## all turn to face the box on the wall and go still but for a tremble; when Vex refuses a
## pull they sink a little. Position is the risers' front edge (room y 112), x = 0.

const Art := preload("res://features/casino/casino_room_art.gd")
const RISERS := [Rect2(96, 64, 112, 48), Rect2(272, 64, 112, 48)]
const BACK_Y := 78.0
const FRONT_Y := 100.0
## Ninja Adventure characters that read as a cult of oddballs (col 0 faces the camera).
const KINDS := [
	"Monk", "Statue", "NinjaMageBlack", "Spirit", "MaskFrog", "Skeleton", "Monk2", "Tengu2",
	"NinjaMasked", "SorcererBlack", "MaskRacoon", "OldMan3", "Shaman", "Vampire", "Noble",
	"GoldStatue", "Monk", "Statue",
]

var mode := "chant"  # chant, stare, hush
var members: Array[Dictionary] = []  # {sprite, frames: [open, closed, back], home: Vector2, group}
var beats := 0
var t := 0.0
var _hush := 0.0


func _ready() -> void:
	var i := 0
	for r: Rect2 in RISERS:
		var left := r.position.x
		# Back row first so the front row draws over it.
		for k in 4:
			_add(KINDS[i % KINDS.size()], Vector2(left + 23 + k * 22, BACK_Y), i)
			i += 1
		for k in 5:
			if r.position.x > 200 and k == 2:
				_add_penguin(Vector2(left + 12 + k * 22, FRONT_Y + 1), i)
			else:
				_add(KINDS[i % KINDS.size()], Vector2(left + 12 + k * 22, FRONT_Y), i)
			i += 1
	# Cool light from behind the risers, warm candle light from the ends.
	for r: Rect2 in RISERS:
		var g := Art.glow(self, Vector2(r.get_center().x, 76) - position, Art.MOON, 70, 0.10, 0.5)
		g.show_behind_parent = true


func _add(kind: String, home: Vector2, index: int) -> void:
	var path := Art.NINJA % kind
	var frames: Array[Texture2D] = [
		Art.region(path, Rect2(0, 0, 16, 16)),
		Art.region(path, Rect2(0, 96, 16, 16)),
		Art.region(path, Rect2(16, 0, 16, 16)),
	]
	_member(frames, home, index, Vector2(0, -8))


func _add_penguin(home: Vector2, index: int) -> void:
	var frames: Array[Texture2D] = [
		Art.region(Art.PENGUIN, Rect2(24, 72, 24, 24)),
		Art.region(Art.PENGUIN, Rect2(0, 72, 24, 24)),
		Art.region(Art.PENGUIN, Rect2(24, 0, 24, 24)),
	]
	_member(frames, home, index, Vector2(0, -12))


func _member(frames: Array[Texture2D], home: Vector2, index: int, offset: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = frames[0]
	s.offset = offset
	s.position = home - position
	s.modulate = Color(0.86, 0.82, 0.92)
	add_child(s)
	members.append({"sprite": s, "frames": frames, "home": s.position, "group": index % 2, "seed": randf() * TAU, "dip": 0.0})


## One beat of the chant. Even beats dip one half of the choir, odd beats the other.
func beat(n: int, seconds: float) -> void:
	beats += 1
	if mode != "chant":
		return
	for m: Dictionary in members:
		if n % 2 == int(m.group):
			m.dip = 1.0
			m["len"] = seconds * 0.7


func set_mode(next: String) -> void:
	if next == mode:
		return
	mode = next
	for m: Dictionary in members:
		(m.sprite as Sprite2D).texture = m.frames[2] if mode == "stare" else m.frames[0]


func hush(seconds := 2.0) -> void:
	_hush = seconds


## Positions and frames right now, so a tour can tell that the choir moves.
func snapshot() -> Array:
	var out: Array = []
	for m: Dictionary in members:
		var s: Sprite2D = m.sprite
		out.append([s.position, s.scale, s.texture])
	return out


func _process(delta: float) -> void:
	t += delta
	_hush = maxf(0.0, _hush - delta)
	for m: Dictionary in members:
		var s: Sprite2D = m.sprite
		var home: Vector2 = m.home
		if mode == "stare":
			# Turned to the box, trembling.
			s.position = home + Vector2(roundf(sin(t * 31.0 + m.seed) * 0.6), 0)
			s.scale = Vector2.ONE
			continue
		var dip: float = m.dip
		if dip > 0.0:
			m.dip = maxf(0.0, dip - delta / maxf(0.08, float(m.get("len", 0.3))))
		var k := sin(float(m.dip) * PI * 0.5)
		s.texture = m.frames[1] if k > 0.35 else m.frames[0]
		s.scale = Vector2(1.0 + k * 0.12, 1.0 - k * 0.14)
		var sway := sin(t * 1.1 + m.seed) * 0.6
		var sink := 2.0 if _hush > 0.0 else 0.0
		s.position = home + Vector2(roundf(sway), roundf(k * 1.5 + sink))
	queue_redraw()


func _draw() -> void:
	for r: Rect2 in RISERS:
		var o := r.position - position
		# Two steps of dark wood with a brass lip on each.
		draw_rect(Rect2(o + Vector2(-2, 0), Vector2(r.size.x + 4, 12)), Color("24170f"))
		draw_rect(Rect2(o + Vector2(-2, 12), Vector2(r.size.x + 4, 12)), Color("160d09"))
		draw_rect(Rect2(o + Vector2(-2, 12), Vector2(r.size.x + 4, 1)), Color("8a6a3a"))
		draw_rect(Rect2(o + Vector2(-6, 24), Vector2(r.size.x + 12, 12)), Color("2b1c13"))
		draw_rect(Rect2(o + Vector2(-6, 36), Vector2(r.size.x + 12, 12)), Color("1a100b"))
		draw_rect(Rect2(o + Vector2(-6, 36), Vector2(r.size.x + 12, 1)), Color("a07a3a"))
		for x in range(int(o.x) + 4, int(o.x + r.size.x), 18):
			draw_rect(Rect2(x, o.y + 40, 1, 7), Color("2b1c13"))
