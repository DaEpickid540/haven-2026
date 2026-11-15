extends CanvasLayer

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
		get_viewport().set_input_as_handled()


func _on_enter_pressed() -> void:
	_close()
	entered.emit()


func _on_stay_pressed() -> void:
	_close()
	stayed.emit()


func _close() -> void:
	overlay.hide()
	get_tree().paused = false
