class_name Flask extends Area2D

@export var heal_amount := 1
@export var big := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _used := false


func _ready() -> void:
	sprite.play(&"big" if big else &"small")


# only taken when hurt so it waits for you otherwise
func _physics_process(_delta: float) -> void:
	if _used or PlayerStats.health <= 0 or PlayerStats.health >= PlayerStats.max_health:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("Player"):
			_drink()
			return


func _drink() -> void:
	_used = true
	PlayerStats.heal(heal_amount)
	Audio.play_sfx("buy")
	Juice.popup(global_position, "+%d" % heal_amount, Juice.HEAL)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 12, 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
