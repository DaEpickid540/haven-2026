extends Node

const MUSIC := {
	"menu": preload("res://Assets/Audio/Music/menu.ogg"),
	"hub": preload("res://Assets/Audio/Music/hub.ogg"),
	"dungeon": preload("res://Assets/Audio/Music/dungeon.ogg"),
}
const SFX := {
	"swing": preload("res://Assets/Audio/SFX/swing.wav"),
	"hit": preload("res://Assets/Audio/SFX/hit.wav"),
	"enemy_die": preload("res://Assets/Audio/SFX/enemy_die.wav"),
	"hurt": preload("res://Assets/Audio/SFX/hurt.wav"),
	"player_die": preload("res://Assets/Audio/SFX/player_die.wav"),
	"coin": preload("res://Assets/Audio/SFX/coin.wav"),
	"buy": preload("res://Assets/Audio/SFX/buy.wav"),
	"error": preload("res://Assets/Audio/SFX/error.wav"),
	"menu_move": preload("res://Assets/Audio/SFX/menu_move.wav"),
	"menu_select": preload("res://Assets/Audio/SFX/menu_select.wav"),
	"pause_in": preload("res://Assets/Audio/SFX/pause_in.wav"),
	"pause_out": preload("res://Assets/Audio/SFX/pause_out.wav"),
}
const VOICES := 8
const FADE := 0.6

var _music := AudioStreamPlayer.new()
var _music_name := ""
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_focus: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.bus = &"Music"
	add_child(_music)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for stream: AudioStreamOggVorbis in MUSIC.values():
		stream.loop = true
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_on_scene_changed.call_deferred()


func play_sfx(sound: String, pitch_jitter := 0.0) -> void:
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = SFX[sound]
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()


func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, FADE)
	tween.tween_callback(func():
		_music.stream = MUSIC.get(track)
		_music.volume_db = 0.0
		if _music.stream:
			_music.play()
		else:
			_music.stop())


# scenes

func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if "main_menu" in path:
		play_music("menu")
	elif "dungeon_room" in path:
		play_music("dungeon")
	else:
		play_music("hub")


# ui

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_sfx.bind("menu_select"))


func _on_focus_changed(control: Control) -> void:
	var moved := _last_focus != null and is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree()
	_last_focus = control
	if moved and control is BaseButton:
		play_sfx("menu_move")
