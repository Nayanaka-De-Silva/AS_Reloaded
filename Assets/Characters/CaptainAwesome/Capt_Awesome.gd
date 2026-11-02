extends CharacterBody2D

@export var speed = 100

@onready var animation = $Animation
var previous_animation_dir = "down"

func _physics_process(_delta):
	get_animation(get_input())
	move_and_slide()

func get_animation(direction):
	var animation_str = ""
	
	if ( direction.x > 0):
		animation_str = "right"
	elif ( direction.x < 0 ):
		animation_str = "left"

	if ( direction.y < 0 ):
		animation_str = "up"
	elif ( direction.y > 0 ):
		animation_str = "down"

	if (animation_str == ""):
		animation_str = "idle_" + previous_animation_dir
	else:
		previous_animation_dir = animation_str
		animation_str = "walk_" + animation_str

	animation.play(animation_str)

func get_input():
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	return input_direction
