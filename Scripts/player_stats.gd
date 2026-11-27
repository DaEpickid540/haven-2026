extends Node

signal coins_changed(amount: int)
signal upgraded(stat: String, level: int)
signal health_changed(current: int, maximum: int)
signal died
signal deaths_changed(deaths: int)

const MAX_LEVEL := 5
const UPGRADE_BASE_COST := {"strength": 10, "speed": 12, "stamina": 8, "health": 10}

const DAMAGE_PER_STRENGTH_LEVEL := 1
const BASE_MAX_STAMINA := 50.0
const STAMINA_PER_LEVEL := 25.0
const BASE_MOVE_SPEED := 100.0
const SPEED_PER_LEVEL := 10.0
const BASE_MAX_HEALTH := 5
const HEALTH_PER_LEVEL := 1

var coins := 0
var max_health := BASE_MAX_HEALTH
var health := max_health
var levels := {"strength": 1, "speed": 1, "stamina": 1, "health": 1}
var deaths := 0
var killed_by := ""
# last death spot
var grave_scene := ""
var grave_position := Vector2.ZERO
# order
const LEVELS := [
	"res://Scenes/dunegon_hub.tscn",
	"res://Scenes/dungeon_room_1.tscn",
	"res://Scenes/dungeon_room_2.tscn",
	"res://Scenes/dungeon_room_3.tscn",
]
const HUB_SCENE := "res://Scenes/dunegon_hub.tscn"
const PUNISH_SCENE := "res://Scenes/troll_room.tscn"
const HUB_HEAL_FRACTION := 0.5
# reached -> refilled
const REFILLS := {
	"res://Scenes/dungeon_room_1.tscn": "res://Scenes/dunegon_hub.tscn",
	"res://Scenes/dungeon_room_2.tscn": "res://Scenes/dungeon_room_1.tscn",
	"res://Scenes/dungeon_room_3.tscn": "res://Scenes/dungeon_room_2.tscn",
	"res://Scenes/dungeon_room_boss.tscn": "res://Scenes/dungeon_room_3.tscn",
}
# deaths in a row
const SUICIDE_STREAK := 3

# scene -> {path: true}
var cleared := {}
# this life
var reached := {}
var made_progress := false
var punished := false
var _quitter_streak := 0
var last_scene := ""


# coins

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func can_afford(price: int) -> bool:
	return coins >= price


func spend_coins(price: int) -> bool:
	if not can_afford(price):
		return false
	coins -= price
	coins_changed.emit(coins)
	return true


# upgrades

func get_level(stat: String) -> int:
	return levels[stat]


func is_maxed(stat: String) -> bool:
	return levels[stat] >= MAX_LEVEL


func get_upgrade_cost(stat: String) -> int:
	return UPGRADE_BASE_COST[stat] * levels[stat]


func buy_upgrade(stat: String) -> bool:
	if is_maxed(stat) or not spend_coins(get_upgrade_cost(stat)):
		return false
	levels[stat] += 1
	if stat == "health":
		# Heal
		max_health += HEALTH_PER_LEVEL
		health += HEALTH_PER_LEVEL
		health_changed.emit(health, max_health)
	upgraded.emit(stat, levels[stat])
	return true


func get_damage() -> int:
	return levels["strength"] * DAMAGE_PER_STRENGTH_LEVEL


func get_max_stamina() -> float:
	return BASE_MAX_STAMINA + (levels["stamina"] - 1) * STAMINA_PER_LEVEL


func get_move_speed() -> float:
	return BASE_MOVE_SPEED + (levels["speed"] - 1) * SPEED_PER_LEVEL


# health

func take_damage(amount: int, source := "") -> bool:
	if health <= 0:
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		killed_by = source
		died.emit()
		return true
	return false


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


# cap
func heal_up_to(fraction: float) -> void:
	health = maxi(health, ceili(max_health * fraction))
	health_changed.emit(health, max_health)


# cleared

func is_cleared(node: Node) -> bool:
	if node.owner == null:
		return false
	var room: Dictionary = cleared.get(node.owner.scene_file_path, {})
	return room.has(node.owner.get_path_to(node))


func mark_cleared(node: Node) -> void:
	made_progress = true
	if node.owner == null or not node.owner.scene_file_path in LEVELS:
		return
	var scene: String = node.owner.scene_file_path
	if not cleared.has(scene):
		cleared[scene] = {}
	cleared[scene][node.owner.get_path_to(node)] = true


# refill
func entered_level(key: String) -> void:
	if not REFILLS.has(key) or reached.has(key):
		return
	reached[key] = true
	cleared.erase(REFILLS[key])


# retry
func respawn() -> String:
	heal_full()
	if punished:
		punished = false
		return PUNISH_SCENE
	return HUB_SCENE


# menu
func resume_scene() -> String:
	if health <= 0:
		return respawn()
	return HUB_SCENE if last_scene.is_empty() else last_scene


# deaths

func get_life() -> int:
	return deaths + 1


func record_death(scene_path: String, at: Vector2) -> void:
	deaths += 1
	# suicide
	if scene_path == PUNISH_SCENE or made_progress:
		_quitter_streak = 0
	else:
		_quitter_streak += 1
	punished = _quitter_streak >= SUICIDE_STREAK
	if punished:
		_quitter_streak = 0
	made_progress = false
	reached.clear()
	grave_scene = scene_path
	grave_position = at
	deaths_changed.emit(deaths)


func clear_grave() -> void:
	grave_scene = ""


# reset

func reset_character() -> void:
	coins = 0
	max_health = BASE_MAX_HEALTH
	health = max_health
	for stat in levels:
		levels[stat] = 1
		upgraded.emit(stat, 1)
	deaths = 0
	cleared.clear()
	reached.clear()
	made_progress = false
	punished = false
	_quitter_streak = 0
	last_scene = ""
	clear_grave()
	deaths_changed.emit(deaths)
	coins_changed.emit(coins)
	health_changed.emit(health, max_health)
