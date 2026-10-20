extends Node
## Autoload "Sfx": short generated sounds (tools/sfx.py writes them to res://audio/).
##   Sfx.play("coin")

const NAMES := [
	"blip", "coin", "cash", "pop", "tick", "reveal_common", "reveal_rare",
	"reveal_epic", "reveal_legendary", "reveal_mythic", "level_up", "error",
	"door", "whoosh", "hit", "boss_down", "chant", "scratch",
]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for n: String in NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.pitch_scale = pitch
			p.play()
			return
