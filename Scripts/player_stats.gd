extends Node
## Shared player numbers (autoload "PlayerStats").
## Autoloads survive scene changes, so coins and upgrades carry over when the
## player dies and the level reloads; that's the "get stronger each run" loop.
##
## Coins:
##   PlayerStats.add_coins(5)            # e.g. when a coin is picked up
##   if PlayerStats.spend_coins(10): ... # returns false if you can't afford it
##
## Upgrades (bought in the shop). The character starts weak at level 1:
##   PlayerStats.get_damage()       # strength: damage per hit
##   PlayerStats.get_max_stamina()  # stamina: size of the dash/stamina bar

signal coins_changed(amount: int)
signal upgraded(stat: String, level: int)
signal health_changed(current: int, maximum: int)
signal died

const MAX_LEVEL := 5
## Cost to go from level N to N+1 is base * N, e.g. strength 10, 20, 30, 40.
const UPGRADE_BASE_COST := {"strength": 10, "stamina": 8}

## Tune these once combat/dash exist.
const DAMAGE_PER_STRENGTH_LEVEL := 1      # Lv1 = 1 damage ... Lv5 = 5
const BASE_MAX_STAMINA := 50.0            # Lv1 = 50
const STAMINA_PER_LEVEL := 25.0           # ... Lv5 = 150

var coins := 0
var max_health := 5
var health := max_health
var levels := {"strength": 1, "stamina": 1}


# --- Coins ---

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


# --- Upgrades ---

func get_level(stat: String) -> int:
	return levels[stat]


func is_maxed(stat: String) -> bool:
	return levels[stat] >= MAX_LEVEL


func get_upgrade_cost(stat: String) -> int:
	return UPGRADE_BASE_COST[stat] * levels[stat]


## Spends coins and raises the stat by one level. Returns false if it's
## already maxed or the player can't afford it.
func buy_upgrade(stat: String) -> bool:
	if is_maxed(stat) or not spend_coins(get_upgrade_cost(stat)):
		return false
	levels[stat] += 1
	upgraded.emit(stat, levels[stat])
	return true


func get_damage() -> int:
	return levels["strength"] * DAMAGE_PER_STRENGTH_LEVEL


func get_max_stamina() -> float:
	return BASE_MAX_STAMINA + (levels["stamina"] - 1) * STAMINA_PER_LEVEL


# --- Health ---

## Lowers health and emits died at 0 and returns true if the hit was fatal
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
