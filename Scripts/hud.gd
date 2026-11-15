extends CanvasLayer
## In-game HUD (Scenes/hud.tscn): health bar, dash bar, coin counter.
## Gameplay code updates it through these functions, e.g. from the player:
##     $Hud.set_dash(stamina, max_stamina)
## The coin counter and health bar follow PlayerStats automatically
## Process mode is Inherit, so the coin animation freezes while paused.

const COIN_FRAMES: Array[Texture2D] = [
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_1.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_2.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_3.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_4.png"),
]
const COIN_FPS := 6.0

@onready var health_bar: ProgressBar = %Health
@onready var dash_bar: ProgressBar = %Dash
@onready var coins_label: Label = %Coins
@onready var coin_icon: TextureRect = %CoinIcon

var _coin_time := 0.0


func _ready() -> void:
	set_coins(PlayerStats.coins)
	PlayerStats.coins_changed.connect(set_coins)
	set_health(PlayerStats.health, PlayerStats.max_health)
	PlayerStats.health_changed.connect(set_health)


func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func set_dash(current: float, maximum: float) -> void:
	dash_bar.max_value = maximum
	dash_bar.value = current


func set_coins(amount: int) -> void:
	coins_label.text = str(amount)


func _process(delta: float) -> void:
	_coin_time += delta
	coin_icon.texture = COIN_FRAMES[int(_coin_time * COIN_FPS) % COIN_FRAMES.size()]
