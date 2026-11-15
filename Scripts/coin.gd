class_name Coin extends Area2D

## A coin pickup: touching it adds `value` to PlayerStats.coins (the HUD
## counter updates by itself) and removes the coin.
@export var value := 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	PlayerStats.add_coins(value)
	queue_free()
