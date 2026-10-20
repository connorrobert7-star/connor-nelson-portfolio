class_name Room
extends Level
## Interiors. Every room has its door in the bottom wall and you arrive just inside.
## W wall top, w wall face, f floor, c counter, t table, r rug, d door.

const ENTRANCE := Vector2i(7, 9)
const LEGEND := {"W": 10, "w": 9, "f": 8, "c": 12, "t": 13, "r": 14, "d": 11}

var exit_spawn := Vector2i.ZERO


func build() -> void:
	legend = LEGEND
	solid = "Wwct"
	follow_camera = false
	for x in [7, 8]:
		add_door(Vector2i(x, map.size() - 1), "village", exit_spawn)
