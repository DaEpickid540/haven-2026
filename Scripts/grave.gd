class_name Grave extends Area2D

const HEAL_FRACTION := 0.5
const BOB_HEIGHT := 2.0
const BOB_TIME := 0.7
const TINT := Color(0.75, 1, 0.8)
const GLOW := Color(1.1, 1.5, 1.15)

@onready var sprite: Sprite2D = $Sprite2D
@onready var heart: Sprite2D = $Heart

var _used := false


func _ready() -> void:
	GameSettings.changed.connect(_apply_setting)
	_apply_setting()
	# green glow and bobbing heart so it stands out from floor bones
	var rest := heart.position.y
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate", GLOW, BOB_TIME).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(heart, "position:y", rest - BOB_HEIGHT, BOB_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", TINT, BOB_TIME).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(heart, "position:y", rest, BOB_TIME).set_trans(Tween.TRANS_SINE)


func _apply_setting() -> void:
	visible = GameSettings.graves


# checked every frame so it still works if you were full hp when you walked on
func _physics_process(_delta: float) -> void:
	if _used or not GameSettings.graves:
		return
	if PlayerStats.health <= 0 or PlayerStats.health >= PlayerStats.max_health:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("Player"):
			_heal()
			return


func _heal() -> void:
	_used = true
	var amount := ceili(PlayerStats.max_health * HEAL_FRACTION)
	PlayerStats.heal(amount)
	PlayerStats.clear_grave()
	Audio.play_sfx("buy")
	Juice.popup(global_position, "+%d" % amount, Juice.HEAL)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 12, 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)
