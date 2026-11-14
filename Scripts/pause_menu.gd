extends CanvasLayer
## Pause menu (Scenes/PauseMenu.tscn). Instance it once in the gameplay scene.
## The "pause" action (Esc) opens/closes it. While open, the rest of the game
## is paused; this node's process_mode is Always so the menu keeps working.

const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"

@onready var overlay: Control = %Overlay
@onready var settings_modal = %SettingsModal  # Scenes/settings_modal.tscn


func _ready() -> void:
	overlay.hide()
	if OS.has_feature("web"):
		%LeaveGame.hide()  # Quitting does nothing in a browser.
	settings_modal.closed.connect(func(): %Settings.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	# Settings (a child, so it sees input first) handles Esc while it's open.
	if overlay.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		resume()
		get_viewport().set_input_as_handled()
	elif not overlay.visible and event.is_action_pressed("pause"):
		pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	get_tree().paused = true
	overlay.show()
	%Resume.grab_focus()


func resume() -> void:
	settings_modal.close()
	overlay.hide()
	get_tree().paused = false


func _on_settings_pressed() -> void:
	settings_modal.open()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false  # Otherwise the menu would load frozen.
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_leave_game_pressed() -> void:
	GameManage.quit_game()
