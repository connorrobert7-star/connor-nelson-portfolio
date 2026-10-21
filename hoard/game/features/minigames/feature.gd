extends HoardFeature
## The arcade: three cabinets (the mine, fishing, the daily dungeon) behind one door.
## On the village plot: a dark front with the three cabinets' colors leaking out, and the
## lantern's flames for today burning over the door.

const ArcadeRoomScript := preload("res://features/minigames/arcade_room.gd")
const TRIM := [Color("ff9a3c"), Color("2ec4b6"), Color("ff6fb5")]
const SHEET := "res://art/packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const ICONS := "res://art/packs/kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"


func id() -> String:
	return "minigames"


func levels() -> Dictionary:
	return {"arcade": ArcadeRoomScript}


func plot_id() -> String:
	return "arcade"


func door_level() -> String:
	return "arcade"


func build_village(village: Level, plot: Rect2i) -> void:
	var front := Node2D.new()
	front.position = Vector2((plot.position.x + plot.size.x / 2.0) * Level.TILE, plot.end.y * Level.TILE)
	village.props.add_child(front)
	var width := maxi(3, plot.size.x)
	var height := maxi(2, plot.size.y)
	for y in height:
		for x in width:
			var t := Sprite2D.new()
			t.texture = ArcadeFx.tex(SHEET, [32, 0 if y == 0 else 16, 16, 16])
			t.position = Vector2((x - width / 2.0 + 0.5) * Level.TILE, -(height - y - 0.5) * Level.TILE)
			t.modulate = Color(0.55, 0.5, 0.65)
			front.add_child(t)
	var door := Sprite2D.new()
	door.texture = ArcadeFx.tex(SHEET, [32, 240, 32, 32])
	door.position = Vector2(0, -16)
	front.add_child(door)
	# The cabinets' colors leak out of the doorway, each on its own breath.
	for i in 3:
		var g := ArcadeFx.glow(front, Vector2((i - 1) * 12, -10), TRIM[i], 22.0, 0.45)
		ArcadeFx.breathe(g, 0.4, 1.0, 0.9 + i * 0.37)
	village.block(Rect2i(plot.position, Vector2i(plot.size.x, maxi(1, plot.size.y - 1))))


func dress_village(village: Level, plot: Rect2i) -> void:
	# Today's flames over the door: one candle each, the spent ones dark.
	var mg: Dictionary = Game.state.get("minigames", {})
	var flames: Dictionary = mg.get("flames", {"max": 3, "left": 3})
	var left := int(flames.get("left", 3))
	var top := Vector2((plot.position.x + plot.size.x / 2.0) * Level.TILE, plot.end.y * Level.TILE - 40)
	for i in int(flames.get("max", 3)):
		var c := Sprite2D.new()
		c.texture = ArcadeFx.tex(ICONS, [64 if i < left else 48, 80, 16, 16])
		c.position = top + Vector2((i - 1) * 10, 0)
		village.dynamic.add_child(c)
		if i < left:
			ArcadeFx.breathe(ArcadeFx.glow(village.dynamic, c.position + Vector2(0, -5), Color("ffb05a"), 14.0, 0.6), 0.5, 1.0, 0.6 + i * 0.2)
