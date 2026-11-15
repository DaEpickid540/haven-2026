extends Node2D

signal interacted

@onready var prompt: Label = $Prompt


func _ready() -> void:
	prompt.hide()
	$TalkZone.body_entered.connect(_on_body.bind(true))
	$TalkZone.body_exited.connect(_on_body.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if prompt.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit()


func _on_body(body: Node2D, in_range: bool) -> void:
	if body.is_in_group("Player"):
		prompt.visible = in_range
