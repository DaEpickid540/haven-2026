extends Control

signal closed

@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var fullscreen_toggle: Button = %FullscreenToggle

const PREVIEW_GAP_MS := 120

var _last_preview := 0


func open() -> void:
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	_refresh_labels()
	show()
	music_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	GameSettings.save_settings()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _on_music_slider_value_changed(value: float) -> void:
	GameSettings.set_music_volume(value)
	_refresh_labels()


func _on_sfx_slider_value_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value)
	_refresh_labels()
	# preview
	var now := Time.get_ticks_msec()
	if now - _last_preview > PREVIEW_GAP_MS:
		_last_preview = now
		Audio.play_sfx("coin")


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.set_fullscreen(enabled)
	_refresh_labels()


func _refresh_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100)
	fullscreen_toggle.text = "On" if fullscreen_toggle.button_pressed else "Off"
