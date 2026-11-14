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
@onready var settings_modal = %SettingsModal  # Scenes/settings_modal.tscn
@onready var dwarf_texture: AtlasTexture = %Dwarf.texture

var _open_modal: Control = null
var _return_focus: Control = null
var _dwarf_time := 0.0


func _ready() -> void:
	%StartGame.grab_focus()
	if OS.has_feature("web"):
		%Leave.hide()  # Quitting does nothing in a browser.
	settings_modal.closed.connect(func(): %Settings.grab_focus())


func _process(delta: float) -> void:
	_dwarf_time += delta
	var column: int = DWARF_IDLE_COLUMNS[int(_dwarf_time * DWARF_FPS) % DWARF_IDLE_COLUMNS.size()]
	var region := dwarf_texture.region
	region.position.x = column * DWARF_CELL_SIZE + DWARF_CROP_OFFSET_X
	dwarf_texture.region = region


func _unhandled_input(event: InputEvent) -> void:
	# Esc (ui_cancel) closes Credits. (Settings handles its own Esc.)
	if _open_modal and event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()


# --- Main buttons ---

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/dunegon_hub.tscn")


func _on_settings_pressed() -> void:
	settings_modal.open()


func _on_credits_pressed() -> void:
	_open(credits_modal, %CreditsClose)


func _on_leave_pressed() -> void:
	GameManage.quit_game()


# --- Modals ---

func _open(modal: Control, focus_target: Control) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	modal.show()
	_open_modal = modal
	focus_target.grab_focus()


func _close_modal() -> void:
	if _open_modal == null:
		return
	_open_modal.hide()
	_open_modal = null
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
