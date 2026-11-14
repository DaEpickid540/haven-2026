extends CanvasLayer
## "Enter the dungeon?" pop-up (Scenes/LeaveHubModal.tscn).
## Call open() to show it; it pauses the game until the player picks one.
## Listen for `entered` / `stayed` to decide what happens next.
## Esc counts as Stay. process_mode is Always so it works while paused.

signal entered
signal stayed

@onready var overlay: Control = %Overlay


func _ready() -> void:
	overlay.hide()


func open() -> void:
	if overlay.visible:
		return
	get_tree().paused = true
	overlay.show()
	%Yes.grab_focus()


func is_open() -> bool:
	return overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_on_stay_pressed()
		get_viewport().set_input_as_handled()  # Don't also open the pause menu.


func _on_enter_pressed() -> void:
	_close()
	entered.emit()


func _on_stay_pressed() -> void:
	_close()
	stayed.emit()


func _close() -> void:
	overlay.hide()
	get_tree().paused = false
