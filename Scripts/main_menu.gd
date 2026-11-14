extends Control

# "dwarf x1.png" is a 5x9 grid of 32px cells. The top row holds idle poses
# (front, back, front), and the dwarf only fills a 16x16 area at the bottom of
# each cell, so the AtlasTexture crops to that area and we flip between the
# two front-facing poses.
const DWARF_IDLE_COLUMNS := [0, 2]
const DWARF_CELL_SIZE := 32
const DWARF_CROP_OFFSET_X := 8
const DWARF_FPS := 2.0

@onready var credits_modal: Control = %CreditsModal
@onready var settings_modal: Control = %SettingsModal
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var fullscreen_toggle: Button = %FullscreenToggle
@onready var dwarf_texture: AtlasTexture = %Dwarf.texture

var _open_modal: Control = null
var _return_focus: Control = null
var _dwarf_time := 0.0


func _ready() -> void:
	%StartGame.grab_focus()
	if OS.has_feature("web"):
		%Leave.hide()  # Quitting does nothing in a browser.


func _process(delta: float) -> void:
	_dwarf_time += delta
	var column: int = DWARF_IDLE_COLUMNS[int(_dwarf_time * DWARF_FPS) % DWARF_IDLE_COLUMNS.size()]
	var region := dwarf_texture.region
	region.position.x = column * DWARF_CELL_SIZE + DWARF_CROP_OFFSET_X
	dwarf_texture.region = region


func _unhandled_input(event: InputEvent) -> void:
	# Esc (ui_cancel) closes whichever modal is open.
	if _open_modal and event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()


# --- Main buttons ---

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/player.tscn")


func _on_settings_pressed() -> void:
	# Show the saved values without triggering the change handlers.
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	_refresh_settings_labels()
	_open(settings_modal, music_slider)


func _on_credits_pressed() -> void:
	_open(credits_modal, %CreditsClose)


func _on_leave_pressed() -> void:
	GameManage.quit_game()


# --- Settings controls (apply live, save on close) ---

func _on_music_slider_value_changed(value: float) -> void:
	GameSettings.set_music_volume(value)
	_refresh_settings_labels()


func _on_sfx_slider_value_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value)
	_refresh_settings_labels()


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.set_fullscreen(enabled)
	_refresh_settings_labels()


func _refresh_settings_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100)
	fullscreen_toggle.text = "On" if fullscreen_toggle.button_pressed else "Off"


# --- Modals ---

func _open(modal: Control, focus_target: Control) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	modal.show()
	_open_modal = modal
	focus_target.grab_focus()


func _close_modal() -> void:
	if _open_modal == null:
		return
	if _open_modal == settings_modal:
		GameSettings.save_settings()
	_open_modal.hide()
	_open_modal = null
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
