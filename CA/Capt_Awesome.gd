extends CharacterBody2D

# EXTERNAL VARIABLES
@export var MAX_SPEED = 100
@export var ACCELERATION	 = 400
@export var FRICTION = 400
@export var ROLL_SPEED = 150
@export var KNOCKBACK = 100
@export var KNOCKBACK_RAND = 10
@export var AUDIO_PITCH_MIN = 0.8
@export var AUDIO_PITCH_MAX = 1.2
@export var health = 4

# STATES
enum {
	MOVE,
	ATTACK,
	ROLL,
	HURT,
	DEAD
}

# INTERNAL VARIABLES
var state = MOVE
var attack_state = 1
var is_dead = false
var velocity = Vector2.ZERO
var roll_vector = Vector2.ZERO
var knockback_vec = Vector2.ZERO
var screen_size_x = ProjectSettings.get_setting("display/window/size/viewport_width")
var screen_size_y = ProjectSettings.get_setting("display/window/size/viewport_height")

# ATTACHED NODES
@onready var punchHitbox = $HitboxPivot/PunchHitbox
@onready var hurtbox = $Hurtbox
@onready var hurtSoundEffect = $HurtSoundEffect
@onready var animationPlayer = $AnimationPlayer
@onready var animationTree = $AnimationTree
@onready var animationState = animationTree.get("parameters/playback")

# SIGNALS
signal CA_dead
signal CA_hurt
signal CA_punch

# BASIC FUNCTIONS
func _ready():
	animationTree.active = true

func _physics_process(delta):
	knockback_vec = knockback_vec.move_toward(Vector2.ZERO, ACCELERATION * delta)
	set_velocity(knockback_vec)
	move_and_slide()
	knockback_vec = velocity
	
	if is_dead:
		state = DEAD
	if Controls.can_move:
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
		
		#Checking for input
		if Input.is_action_just_pressed("Roll"):
			state = ROLL
		if Input.is_action_just_pressed("Attack"):
			state = ATTACK


# STATE HANDLERS
func move_state(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	# Check if CA is moving
	if input_vector != Vector2.ZERO:
		# CA is moving
		roll_vector = input_vector
		punchHitbox.knockback_vec = roll_vector
		direction_change(input_vector)
		move_to(input_vector, delta)
	else:
		# CA is not
		stop(delta)

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
	set_velocity(velocity)
	move_and_slide()
	velocity = velocity


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
	if knockback_vec.x == 0:
		knockback_vec.x = randf_range(-KNOCKBACK_RAND, KNOCKBACK_RAND)
	elif knockback_vec.y == 0:
		knockback_vec.y = randf_range(-KNOCKBACK_RAND, KNOCKBACK_RAND)
	hurtbox.create_hit_effect("Enemy")
	hurtSoundEffect.pitch_scale = randf_range(AUDIO_PITCH_MIN, AUDIO_PITCH_MAX)
	hurtSoundEffect.play()
	CA_Stats.health -= 1
	if health <= 0:
		is_dead = true
		state = DEAD
		animationState.travel("Die")
		emit_signal("CA_dead")
	else:
		state = HURT
		emit_signal("CA_hurt")


func _on_PunchHitbox_area_entered(area):
	emit_signal("CA_punch")
