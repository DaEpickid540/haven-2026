extends Node

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MAX_VOLUME := 0.7

var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var life_counter := true
var graves := true


func _ready() -> void:
	load_settings()
	apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_window()


func set_life_counter(enabled: bool) -> void:
	life_counter = enabled
	changed.emit()


func set_graves(enabled: bool) -> void:
	graves = enabled
	changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = _read_volume(cfg, "audio", "music_volume", music_volume)
	sfx_volume = _read_volume(cfg, "audio", "sfx_volume", sfx_volume)
	var fs = cfg.get_value("video", "fullscreen", fullscreen)
	fullscreen = fs if fs is bool else fullscreen
	life_counter = _read_bool(cfg, "gameplay", "life_counter", life_counter)
	graves = _read_bool(cfg, "gameplay", "graves", graves)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "life_counter", life_counter)
	cfg.set_value("gameplay", "graves", graves)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Couldn't save settings to %s (error %d)" % [PATH, err])


func apply() -> void:
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	_apply_window()


func _read_volume(cfg: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value = cfg.get_value(section, key, fallback)
	if value is float or value is int:
		return clampf(value, 0.0, 1.0)
	return fallback


func _read_bool(cfg: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value = cfg.get_value(section, key, fallback)
	return value if value is bool else fallback


func _apply_bus(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Audio bus '%s' is missing (see default_bus_layout.tres)" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(volume * MAX_VOLUME))
	AudioServer.set_bus_mute(idx, volume <= 0.0)


func _apply_window() -> void:
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
