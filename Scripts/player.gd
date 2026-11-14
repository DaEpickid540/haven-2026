extends CharacterBody2D

const SPEED = 100.0
#Yo what's this oh, wait this is the game thingy
func _physics_process(delta: float) -> void:
	var input_vector = Input.get_vector("left","right","up","down")
	
	velocity = input_vector * SPEED
	move_and_slide()
