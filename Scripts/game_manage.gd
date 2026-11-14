
extends Node

const MAIN_SCENE = "res://Scenes/main.tscn"
const STARTING_WORLD = "res://Scenes/dungeon_hub.tscn"

var is_new_game: bool = false
var starting_world_path: String = ""


func start_new_game() -> void:
	is_new_game = true
	starting_world_path = STARTING_WORLD

	get_tree().change_scene_to_file(MAIN_SCENE)


func continue_game() -> void:
	is_new_game = false

	get_tree().change_scene_to_file(MAIN_SCENE)


func quit_game() -> void:
	get_tree().quit()
