extends Node2D

signal interacted

@onready var talk_zone: Area2D = $TalkZone
@onready var prompt: Label = $Prompt

var player_in_range := false


func _ready() -> void:
	prompt.hide()
	talk_zone.body_entered.connect(_on_talk_zone_body_entered)
	talk_zone.body_exited.connect(_on_talk_zone_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not get_tree().paused and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit()


func _on_talk_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		prompt.show()


func _on_talk_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		prompt.hide()
