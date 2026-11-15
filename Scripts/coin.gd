class_name Coin extends Area2D

@export var value := 1

@onready var sprite_2d: Sprite2D = $Sprite2D # Adjust this if your sprite has a different name

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	
	PlayerStats.add_coins(value)
	
	$CollisionShape2D.set_deferred("disabled", true)
	
	var tween := create_tween().set_parallel(true)
	
	tween.tween_property(self, "global_position", global_position + Vector2(0, -24), 0.35)
	
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	
	tween.chain().tween_callback(queue_free)
