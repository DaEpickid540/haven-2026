extends Control

@onready var credits_modal: Control = %CreditsModal
@onready var credits_close: Button = %Close
@onready var credits_button: Button = $"VBoxContainer/Credits"


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/player.tscn")


func _on_credits_pressed() -> void:
	credits_modal.show()
	credits_close.grab_focus()


func _on_credits_close_pressed() -> void:
	credits_modal.hide()
	credits_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Esc (ui_cancel) closes the credits modal.
	if credits_modal.visible and event.is_action_pressed("ui_cancel"):
		_on_credits_close_pressed()
		get_viewport().set_input_as_handled()
