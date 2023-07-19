extends CharacterBody2D

@export var speed = 100

@onready var animation = $Animation

func _physics_process(delta):
	get_animation(get_input())
	move_and_slide()

func get_animation(direction):
	if ( direction.y < 0 ):
		animation.play("walk_up")
	elif ( direction.y > 0 ):
		animation.play("walk_down")
	
	if ( direction.x > 0):
		animation.play("walk_right")
	elif ( direction.x < 0 ):
		animation.play("walk_left")
	
	if ( direction.x == 0 and direction.y == 0):
		animation.play("idle")

func get_input():
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	return input_direction
