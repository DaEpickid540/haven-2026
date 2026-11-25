class_name Trap extends Area2D

# frames play in order and loop, durations line up with frames
@export var display_name := "Trap"
@export var damage := 1
@export var frames: Array[Texture2D] = []
@export var durations: PackedFloat32Array = []
@export var hurt_frames: PackedInt32Array = []
# lets traps next to each other go off at different times
@export var phase_offset := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

var _frame := 0
var _time := 0.0
var _hit_this_cycle := false


func _ready() -> void:
	_set_frame(0)
	_advance(phase_offset)


func _physics_process(delta: float) -> void:
	_advance(delta)
	if _frame in hurt_frames and not _hit_this_cycle:
		for body in get_overlapping_bodies():
			if body is Player and body.take_damage(damage, hitbox.global_position, display_name):
				_hit_this_cycle = true


func _advance(delta: float) -> void:
	if durations.is_empty():
		return
	_time += delta
	while _time >= durations[_frame]:
		_time -= durations[_frame]
		_set_frame((_frame + 1) % durations.size())


func _set_frame(index: int) -> void:
	_frame = index
	if index == 0:
		_hit_this_cycle = false
	if index < frames.size():
		sprite.texture = frames[index]


func is_dangerous() -> bool:
	return _frame in hurt_frames
