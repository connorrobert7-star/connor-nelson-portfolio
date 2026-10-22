extends Node
## Autoload "Sfx": short generated sounds (tools/sfx.py writes them to res://audio/)
## and any pack sound by path, on four buses (Music, Ambience, SFX, UI).
##   Sfx.play("coin")
##   Sfx.play_path("res://art/packs/kenney-casino-audio/Audio/chips-stack-1.ogg", 1.0, -8.0)
##   Sfx.ui("tap")            the shared UI set: tap, select, open, close, hover, press
##   Sfx.duck(-8.0, 0.6)      dip Music and Ambience under a big reveal
## Sounds at the default pitch get a little jitter (+-4%) so repeats don't machine-gun.
## When all voices are busy the oldest one is stolen rather than dropping the new sound.

const NAMES := [
	"blip", "coin", "cash", "pop", "tick", "reveal_common", "reveal_rare",
	"reveal_epic", "reveal_legendary", "reveal_mythic", "level_up", "error",
	"door", "whoosh", "hit", "boss_down", "chant", "scratch",
]
const BUSES := ["Music", "Ambience", "SFX", "UI"]
const VOICES := 12
const JITTER := 0.04
const UI_DIR := "res://art/packs/kenney-interface-sounds/Audio/"
const UI_SOUNDS := {
	"tap": [UI_DIR + "click_002.ogg", -18.0],
	"select": [UI_DIR + "select_002.ogg", -14.0],
	"open": [UI_DIR + "open_001.ogg", -14.0],
	"close": [UI_DIR + "close_003.ogg", -14.0],
	"hover": ["res://art/packs/kenney-ui-audio/Audio/rollover2.ogg", -16.0],
	"press": [UI_DIR + "click_004.ogg", -12.0],
	"nope": [UI_DIR + "error_004.ogg", -16.0],
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _started: Dictionary = {}  # player -> msec it started, for stealing the oldest
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n: String in NAMES:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


## Play any audio file from the packs on a bus (SFX by default).
func play_path(path: String, pitch := 1.0, volume_db := -6.0, bus := "SFX") -> void:
	if not _streams.has(path):
		if not ResourceLoader.exists(path):
			return
		_streams[path] = load(path)
	_voice(_streams[path], pitch, volume_db, bus)


func play(sound: String, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	_voice(_streams[sound], pitch, -6.0, "SFX")


## The shared UI set, so every button and overlay sounds the same.
func ui(kind: String, pitch := 1.0) -> void:
	if not UI_SOUNDS.has(kind):
		return
	var s: Array = UI_SOUNDS[kind]
	play_path(s[0], pitch, s[1], "UI")


## Dip Music and Ambience by `db` for `seconds`, then bring them back.
func duck(db := -8.0, seconds := 0.6) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	for b: String in ["Music", "Ambience"]:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		_duck_tween.parallel().tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(i, v), AudioServer.get_bus_volume_db(i), db, 0.08)
	_duck_tween.tween_interval(seconds)
	for b: String in ["Music", "Ambience"]:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		_duck_tween.parallel().tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(i, v), db, 0.0, 0.5)


func _voice(stream: AudioStream, pitch: float, volume_db: float, bus: String) -> void:
	var pick: AudioStreamPlayer = null
	var oldest := 1 << 62
	for p in _players:
		if not p.playing:
			pick = p
			break
		var t: int = _started.get(p, 0)
		if t < oldest:
			oldest = t
			pick = p
	if pick == null:
		return
	if pitch == 1.0:
		pitch = randf_range(1.0 - JITTER, 1.0 + JITTER)
	pick.stop()
	pick.stream = stream
	pick.pitch_scale = pitch
	pick.volume_db = volume_db
	pick.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	pick.play()
	_started[pick] = Time.get_ticks_msec()
