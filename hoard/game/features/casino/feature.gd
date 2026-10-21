extends HoardFeature
## The casino: the room the game opens in (Main.START_LEVEL), Vex the dealer, and, once the
## village has a casino plot, a dark hall with the neon chalice and a door back in.

const Art := preload("res://features/casino/casino_room_art.gd")
const Props := preload("res://features/casino/casino_room_props.gd")


func id() -> String:
	return "casino"


func levels() -> Dictionary:
	return {"casino": CasinoRoom}


func npcs() -> Dictionary:
	# Vex's hood (Shattered Pixel Dungeon's necromancer, first row) for any dialogue portrait.
	return {"croupier": {"texture": Art.region(Art.NECRO, Rect2(0, 0, 256, 16)), "frame": 0, "hframes": 16}}


func plot_id() -> String:
	return "casino"


func door_level() -> String:
	return "casino"


## Once, when the village is built: a dark hall on the plot, the neon chalice over the door,
## a candle with an eye on each side. The village adds the door itself.
func build_village(village: Level, plot: Rect2i) -> void:
	var px := Vector2(plot.position * Level.TILE)
	var size := Vector2(plot.size * Level.TILE)
	var hall := _Hall.new()
	hall.size = size
	hall.position = px + Vector2(size.x / 2.0, size.y)
	village.props.add_child(hall)
	var neon := Props.Neon.new()
	neon.position = px + Vector2(size.x / 2.0, size.y - 34)
	neon.z_index = 1
	village.props.add_child(neon)
	for side in [-1, 1]:
		var candle := Props.Candle.new(7)
		candle.position = px + Vector2(size.x / 2.0 + side * 22, size.y + 2)
		candle.watch = village.leader
		village.props.add_child(candle)
	if plot.size.y > 1:
		village.block(Rect2i(plot.position, Vector2i(plot.size.x, plot.size.y - 1)))


## Every state change: when a special shell is chambered, the hall's window burns its color.
func dress_village(village: Level, plot: Rect2i) -> void:
	var box: Dictionary = Game.state.get("casino", {}).get("box", {})
	if not box.get("next_is_special", false):
		return
	var at := Vector2(plot.position * Level.TILE) + Vector2(plot.size.x * Level.TILE / 2.0, 10)
	Art.glow(village.dynamic, at, Art.rarity(str(box.get("next_tier", "legendary"))), 22, 0.45)


class _Hall:
	extends Node2D
	## The casino from outside: a black hall with a brass trim line and a lit doorway.

	var size := Vector2(64, 48)

	func _draw() -> void:
		var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
		draw_rect(r, Color("120c18"))
		draw_rect(Rect2(r.position, Vector2(size.x, 3)), Color("2a1d33"))
		draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(size.x, 1)), Color("8a6a3a"))
		draw_rect(Rect2(Vector2(-8, -18), Vector2(16, 18)), Color("2a1420"))
		draw_rect(Rect2(Vector2(-6, -16), Vector2(12, 16)), Color(1.0, 0.85, 0.7, 0.18))
