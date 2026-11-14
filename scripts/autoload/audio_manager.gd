extends Node
## Global audio helper (autoloaded as `AudioManager`).
##
##   AudioManager.play_sfx("jump_1")                 # file name from res://assets/sounds
##   AudioManager.play_sfx("hit_1", -4.0, 0.1)       # volume_db, random pitch +/- 10%
##   AudioManager.play_sfx(preload("res://some.wav"))
##   AudioManager.play_music("adventure_theme")      # crossfades + loops automatically
##   AudioManager.stop_music()
##   AudioManager.set_bus_volume("Music", 0.5)       # linear 0..1

const SFX_DIR := "res://assets/sounds/"
const MUSIC_DIR := "res://assets/music/"
const SFX_VOICES := 16
const EXTENSIONS := [".wav", ".ogg", ".mp3"]

var current_music := ""

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while the tree is paused
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		add_child(m)
		_music_players.append(m)


func _exit_tree() -> void:
	for p in _sfx_players + _music_players:
		p.stop()
		p.stream = null
	_cache.clear()


func play_sfx(sound: Variant, volume_db := 0.0, pitch_variance := 0.0) -> void:
	var stream := _resolve(SFX_DIR, sound)
	if stream == null:
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.play()


## Plays one random sound from a list, e.g. play_random_sfx(["footstep_1", "footstep_2", "footstep_3"])
func play_random_sfx(sounds: Array, volume_db := 0.0, pitch_variance := 0.05) -> void:
	if not sounds.is_empty():
		play_sfx(sounds.pick_random(), volume_db, pitch_variance)


func play_music(track: Variant, fade_time := 1.0, volume_db := 0.0) -> void:
	var key := str(track) if track is String else (track as AudioStream).resource_path
	if key == current_music and _music_players[_active_music].playing:
		return
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	_enable_loop(stream)
	current_music = key

	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	incoming.stream = stream
	incoming.volume_db = -40.0 if fade_time > 0.0 else volume_db
	incoming.play()

	if fade_time > 0.0:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(incoming, "volume_db", volume_db, fade_time)
		if outgoing.playing:
			tw.tween_property(outgoing, "volume_db", -40.0, fade_time)
			tw.chain().tween_callback(outgoing.stop)
	else:
		outgoing.stop()


func stop_music(fade_time := 1.0) -> void:
	current_music = ""
	var p := _music_players[_active_music]
	if fade_time <= 0.0:
		p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, fade_time)
	tw.tween_callback(p.stop)


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func _resolve(dir: String, sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound
	var name := str(sound)
	if _cache.has(name):
		return _cache[name]
	for ext in EXTENSIONS:
		var path: String = name if name.begins_with("res://") else dir + name + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_cache[name] = s
			return s
	push_warning("AudioManager: sound not found: %s" % name)
	return null


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set("loop", true)
