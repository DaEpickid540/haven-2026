extends Node

@onready var game_world: Node2D = $GameWorld

var current_world: Node2D


func _ready() -> void:
	pass


func load_world(scene_path: String) -> void:
	var world_scene = load(scene_path)

	if world_scene == null:
		push_error("Could not load world: " + scene_path)
		return

	if current_world != null:
		game_world.remove_child(current_world)
		current_world.queue_free()

	current_world = world_scene.instantiate()
	game_world.add_child(current_world)
