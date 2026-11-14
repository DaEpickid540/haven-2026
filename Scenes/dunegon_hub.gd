extends Node2D

@onready var player: CharacterBody2D = $Player

signal begin_descent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player.global_position.y < 0:
		print("dude")
		begin_descent.emit()
