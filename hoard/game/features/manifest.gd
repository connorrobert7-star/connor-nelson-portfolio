class_name FeatureManifest
## Every feature the game loads. The orchestrator adds one line per feature.

const FEATURES: Array[Script] = [
	preload("res://features/casino/feature.gd"),
	preload("res://features/minigames/feature.gd"),
	preload("res://features/gate/feature.gd"),
	preload("res://features/followers/feature.gd"),
	preload("res://features/village/feature.gd"),
	preload("res://features/buildings/feature.gd"),
	preload("res://features/helper/feature.gd"),
]
