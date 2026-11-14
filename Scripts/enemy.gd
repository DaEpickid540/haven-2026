extends CharacterBody2D

@export var range = 128

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback


func _physics_process(delta: float) -> void:
	var state = playback.get_current_node()
	match state:
		"Idle":
			pass
		"Chase":
			var player = get_player()
			
			
func get_player() -> Player:
	return get_tree().get_first_node_in_group("Player")
	
func is_player_in_range() -> bool:
	var result = false
	var player: = get_player()
	
	if player is Player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player < range:
			result = true
	return result

pass
