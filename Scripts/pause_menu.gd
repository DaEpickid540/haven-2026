extends CanvasLayer

const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"

@onready var overlay: Control = %Overlay
@onready var settings_modal = %SettingsModal


func _ready() -> void:
	overlay.hide()
	if OS.has_feature("web"):
		%LeaveGame.hide()
	settings_modal.closed.connect(func(): %Settings.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
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
	Transition.change_scene(MAIN_MENU_SCENE)


func _on_leave_game_pressed() -> void:
	GameManage.quit_game()
