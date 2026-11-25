extends CanvasLayer

const COIN_FRAMES: Array[Texture2D] = [
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_1.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_2.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_3.png"),
	preload("res://Assets/2D Pixel Dungeon Asset Pack/items and trap_animation/coin/coin_4.png"),
]
const COIN_FPS := 6.0

@onready var health_bar: ProgressBar = %Health
@onready var stamina_bar: ProgressBar = %Stamina
@onready var coins_label: Label = %Coins
@onready var coin_icon: TextureRect = %CoinIcon
@onready var life_row: HBoxContainer = %LifeRow
@onready var life_label: Label = %Life

var _coin_time := 0.0


func _ready() -> void:
	set_coins(PlayerStats.coins)
	PlayerStats.coins_changed.connect(set_coins)
	set_health(PlayerStats.health, PlayerStats.max_health)
	PlayerStats.health_changed.connect(set_health)
	_refresh_life()
	PlayerStats.deaths_changed.connect(_refresh_life.unbind(1))
	GameSettings.changed.connect(_refresh_life)


func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func set_stamina(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func set_coins(amount: int) -> void:
	coins_label.text = str(amount)


func _refresh_life() -> void:
	life_row.visible = GameSettings.life_counter
	life_label.text = "Life %d" % PlayerStats.get_life()


func _process(delta: float) -> void:
	_coin_time += delta
	coin_icon.texture = COIN_FRAMES[int(_coin_time * COIN_FPS) % COIN_FRAMES.size()]
