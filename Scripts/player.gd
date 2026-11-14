extends CharacterBody2D

var speed = 100.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback

var input_vector = Vector2.ZERO

const SPEED = 100.0
#Yo what's this oh, wait this is the game thingy
func _physics_process(delta: float) -> void:
	var state = playback.get_current_node()
	match state:
		"MoveState":
			move_state(delta)
		"AttackState":
			input_vector = Vector2.ZERO
		
		
	velocity = input_vector * speed
	move_and_slide()

func move_state(delta: float) -> void:
	input_vector = Input.get_vector("left","right","up","down")
			
	if input_vector != Vector2.ZERO:
		print("moving")
		var direction_vector = Vector2(input_vector.x, -input_vector.y)
		update_blend_positions(direction_vector)
				
	if Input.is_action_just_pressed("attack"):
		playback.travel("AttackState")
	if Input.is_action_just_pressed("attack"):
		playback.travel("AttackState")
	if Input.is_action_just_pressed("dash"):
		speed=150.0
	else: speed=100.0


func update_blend_positions(direction_vector: Vector2) -> void:
	animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position",direction_vector)
	animation_tree.set("parameters/StateMachine/MoveState/StandState/blend_position", direction_vector)
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", direction_vector)
