extends KinematicBody2D

# EXTERNAL VARIABLES
export var MAX_SPEED = 100
export var ACCELERATION	 = 400
export var FRICTION = 500
export var ROLL_SPEED = 150
export var KNOCKBACK = 100
export var health = 4

# STATES
enum {
	MOVE,
	ATTACK,
	ROLL,
	HURT,
	DEAD
}

# INTERNAL VARIABLES
var velocity = Vector2.ZERO
var state = MOVE
var roll_vector = Vector2.ZERO
var attack_state = 1
var knockback_vec = Vector2.ZERO
var is_dead = false
var stats = CA_Stats
var can_move
var screen_size_x = ProjectSettings.get_setting("display/window/size/width")
var screen_size_y = ProjectSettings.get_setting("display/window/size/height")

# ATTACHED NODES
onready var punchHitbox = $HitboxPivot/PunchHitbox
onready var hurtbox = $Hurtbox
onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")

# SIGNALS
signal CA_dead

# BASIC FUNCTIONS
func _ready():
	animationTree.active = true

func _physics_process(delta):
	can_move = Controls.can_move
	
	knockback_vec = knockback_vec.move_toward(Vector2.ZERO, ACCELERATION * delta)
	knockback_vec = move_and_slide(knockback_vec)
	
	if is_dead:
		state = DEAD
	if can_move:
		match state:
			MOVE:
				move_state(delta)
			ROLL:
				roll_state()
			ATTACK:
				attack_state()
			HURT:
				animationState.travel("Hurt")
			DEAD:
				animationState.travel("Die")


# STATE HANDLERS
func move_state(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		roll_vector = input_vector
		punchHitbox.knockback_vec = roll_vector
		direction_change(input_vector)
		move_to(input_vector, delta)
	else:
		stop(delta)
	
	if Input.is_action_just_pressed("Roll"):
		state = ROLL
	if Input.is_action_just_pressed("Attack"):
		state = ATTACK

func roll_state():
	velocity = roll_vector * ROLL_SPEED
	animationState.travel("Roll")
	move()

func attack_state():
	velocity = Vector2.ZERO
	if attack_state == 1:
		attack_state = 2
		animationState.travel("Attack_1")
	else:
		attack_state = 1
		animationState.travel("Attack_2")


# MOVEMENT FUNCTIONS
func direction_change(input_vector):
	animationTree.set("parameters/Idle/blend_position", input_vector)
	animationTree.set("parameters/Run/blend_position", input_vector)
	animationTree.set("parameters/Roll/blend_position", input_vector)
	animationTree.set("parameters/Attack_1/blend_position", input_vector)
	animationTree.set("parameters/Attack_2/blend_position", input_vector)
	animationTree.set("parameters/Hurt/blend_position", input_vector)
	animationTree.set("parameters/Die/blend_position", input_vector)

func move_to(input_vector, delta):
	animationState.travel("Run")
	velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	move()

func stop(delta):
	animationState.travel("Idle")
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move()

func move():
	velocity = move_and_slide(velocity)
	position.x = clamp(position.x, 5, screen_size_x-5)
	position.y = clamp(position.y, 5, screen_size_y-5)


# ANIMATION FINISHED FUNCTIONS
func roll_animation_finished():
	state = MOVE

func attack_animation_finished():
	state = MOVE

func hurt_animation_finished():
	state = MOVE


# SIGNAL CALLBACKS
func _on_Hurtbox_area_entered(area):
	health -= 1
	knockback_vec = area.knockback_vec * KNOCKBACK
	hurtbox.create_hit_effect("Enemy")
	stats.health -= 1
	if health <= 0:
		is_dead = true
		state = DEAD
		animationState.travel("Die")
		emit_signal("CA_dead")
	state = HURT
