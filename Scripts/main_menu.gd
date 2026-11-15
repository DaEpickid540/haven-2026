extends Control

const DWARF_IDLE_COLUMNS := [0, 2]
const DWARF_CELL_SIZE := 32
const DWARF_CROP_OFFSET_X := 8
const DWARF_FPS := 2.0
const CONTROL_ROWS := [
	["Move", ""],
	["Attack", "attack"],
	["Dash", "dash"],
	["Interact", "interact"],
	["Pause", "pause"],
]

@onready var credits_modal: Control = %CreditsModal
@onready var controls_modal: Control = %ControlsModal
@onready var settings_modal = %SettingsModal
@onready var dwarf_texture: AtlasTexture = %Dwarf.texture

var _open_modal: Control = null
var _return_focus: Control = null
var _dwarf_time := 0.0


func _ready() -> void:
	%StartGame.grab_focus()
	if OS.has_feature("web"):
		%Leave.hide()
	settings_modal.closed.connect(func(): %Settings.grab_focus())
	_build_controls()


func _process(delta: float) -> void:
	_dwarf_time += delta
	var column: int = DWARF_IDLE_COLUMNS[int(_dwarf_time * DWARF_FPS) % DWARF_IDLE_COLUMNS.size()]
	var region := dwarf_texture.region
	region.position.x = column * DWARF_CELL_SIZE + DWARF_CROP_OFFSET_X
	dwarf_texture.region = region


func _unhandled_input(event: InputEvent) -> void:
	if _open_modal and event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()


# buttons

func _on_start_game_pressed() -> void:
	Transition.change_scene("res://Scenes/dunegon_hub.tscn")


func _on_settings_pressed() -> void:
	settings_modal.open()


func _on_controls_pressed() -> void:
	_open(controls_modal, %ControlsClose)


func _on_credits_pressed() -> void:
	_open(credits_modal, %CreditsClose)


func _on_leave_pressed() -> void:
	GameManage.quit_game()


# controls

func _build_controls() -> void:
	for row: Array in CONTROL_ROWS:
		var keys: String = "WASD / Arrows" if row[1] == "" else _action_keys(row[1])
		var action := Label.new()
		action.theme_type_variation = &"MutedLabel"
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action.text = row[0]
		var key := Label.new()
		key.text = keys
		%ControlsGrid.add_child(action)
		%ControlsGrid.add_child(key)


func _action_keys(action: StringName) -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var name := OS.get_keycode_string(code)
		match code:
			KEY_ESCAPE:
				name = "Esc"
			KEY_SHIFT, KEY_CTRL, KEY_ALT:
				if key.location == KEY_LOCATION_LEFT:
					name = "L-" + name
				elif key.location == KEY_LOCATION_RIGHT:
					name = "R-" + name
		names.append(name)
	return " / ".join(names)


# modals

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
