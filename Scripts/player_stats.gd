extends Node

signal coins_changed(amount: int)
signal upgraded(stat: String, level: int)
signal health_changed(current: int, maximum: int)
signal died

const MAX_LEVEL := 5
const UPGRADE_BASE_COST := {"strength": 10, "speed": 12, "stamina": 8, "health": 10}

const DAMAGE_PER_STRENGTH_LEVEL := 1
const BASE_MAX_STAMINA := 50.0
const STAMINA_PER_LEVEL := 25.0
const BASE_MOVE_SPEED := 100.0
const SPEED_PER_LEVEL := 10.0
const BASE_MAX_HEALTH := 20
const HEALTH_PER_LEVEL := 1

var coins := 0
var max_health := BASE_MAX_HEALTH
var health := max_health
var levels := {"strength": 1, "speed": 1, "stamina": 1, "health": 1}


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

func take_damage(amount: int) -> bool:
	if health <= 0:
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
		return true
	return false


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


# reset

func reset_character() -> void:
	coins = 0
	max_health = BASE_MAX_HEALTH
	health = max_health
	for stat in levels:
		levels[stat] = 1
		upgraded.emit(stat, 1)
	coins_changed.emit(coins)
	health_changed.emit(health, max_health)
