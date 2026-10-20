extends Node
## Autoload "Features": the loaded HoardFeature instances and lookups across them.

var all: Array[HoardFeature] = []
var _levels: Dictionary = {}  # level_id -> Script
var _npcs: Dictionary = {}  # npc_id -> {texture, frame, hframes}


func _ready() -> void:
	for script: Script in FeatureManifest.FEATURES:
		var f: HoardFeature = script.new()
		all.append(f)
		_levels.merge(f.levels())
		_npcs.merge(f.npcs())


func level_script(level_id: String) -> Script:
	return _levels.get(level_id)


func npc(npc_id: String) -> Dictionary:
	return _npcs.get(npc_id, {})


func for_plot(plot_id: String) -> HoardFeature:
	for f in all:
		if f.plot_id() == plot_id:
			return f
	return null
