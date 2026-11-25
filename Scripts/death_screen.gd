extends CanvasLayer

const HUB_SCENE := "res://Scenes/dunegon_hub.tscn"
const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"

@onready var overlay: Control = %Overlay


func _ready() -> void:
	overlay.hide()


func open() -> void:
	%Cause.visible = not PlayerStats.killed_by.is_empty()
	%Cause.text = "Slain by %s" % PlayerStats.killed_by
	%Coins.text = "Coins kept: %d" % PlayerStats.coins
	%Lives.visible = GameSettings.life_counter
	%Lives.text = "Deaths: %d" % PlayerStats.deaths
	overlay.modulate.a = 0.0
	overlay.show()
	get_tree().paused = true
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.6)
	%Retry.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()


func _on_retry_pressed() -> void:
	Transition.change_scene(HUB_SCENE)


func _on_main_menu_pressed() -> void:
	Transition.change_scene(MAIN_MENU_SCENE)
