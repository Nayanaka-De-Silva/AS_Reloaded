extends CharacterBody2D

# EXTERNAL VARIABLES
@export var KNOCKBACK_FRICTION = 300
@export var KNOCKBACK = 100
@export var KNOCKBACK_RAND = 20
@export var AUDIO_PITCH_MIN = 1.2
@export var AUDIO_PITCH_MAX = 1.6
@export var MAX_SPEED = 80
@export var ACCELERATION = 300
@export var FRICTION = 300
@export var ATTACK_TIME = 2.5
@export var health = 2

# STATE VARIABLE
enum {
	CHASE,
	IDLE,
	ATTACK,
	DEAD
}

# INTERNAL VARIABLES
var knockback_vec = Vector2.ZERO
var state = IDLE
var velocity = Vector2.ZERO
var attack_ready = false
var is_dead = false

# ATTACHED NODES
@onready var detectionZone = $DetectionZone
@onready var attackTimer = $AttackTimer
@onready var hurtbox = $Hurtbox
@onready var punchHitbox = $Hitpivot/PunchHitbox
@onready var hurtSoundEffect = $HurtSoundEffect
@onready var animationPlayer = $AnimationPlayer
@onready var animationTree = $AnimationTree
@onready var animationState = animationTree.get("parameters/playback")

# SIGNALS
signal enemy_dead

# BASIC FUNCTIONS
func _ready():
	animationTree.active = true
	attackTimer.start(ATTACK_TIME)
	add_to_group("Enemies")

func _physics_process(delta):
	knockback_vec = knockback_vec.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	set_velocity(knockback_vec)
	move_and_slide()
	knockback_vec = velocity
	
	var player = detectionZone.target
	
	if Controls.can_move and !is_dead:
		match state:
			IDLE:
				Idle_state(delta)
			CHASE:
				Chase_state(player, delta)
			ATTACK:
				Attack_state(delta)
			DEAD:
				stop(delta)
				animationState.travel("Die")
				is_dead = true
	
	print("Robber state: ", state)

# STATE HANDLING FUNCTIONS
func Idle_state(delta):
	stop(delta)
	animationState.travel("Idle")
	if detectionZone.target_found():
		state = CHASE

func Chase_state(target, delta):
	if target != null:
		var direction = global_position.direction_to(target.global_position).normalized()
		direction_change(direction)
		punchHitbox.knockback_vec = direction
		move_to(direction, delta)
	else:
		state = IDLE

func Attack_state(delta):
	# Attack state code
	stop(delta)
	if attack_ready:
		animationState.travel("Attack")
	else:
		animationState.travel("Idle")

# MOVEMENT FUNCTIONS
func direction_change(input_vector):
	animationTree.set("parameters/Idle/blend_position", input_vector)
	animationTree.set("parameters/Run/blend_position", input_vector)
	animationTree.set("parameters/Attack/blend_position", input_vector)
	animationTree.set("parameters/Die/blend_position", input_vector)

func move_to(input_vector, delta):
	animationState.travel("Run")
	velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	move()

func stop(delta):
	if state != ATTACK and not is_dead:
		animationState.travel("Idle")
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move()

func move():
	set_velocity(velocity)
	move_and_slide()
	velocity = velocity

# ANIMATION FINISHED FUNCTIONS
func attack_animation_finished():
	attack_ready = false
	attackTimer.start(ATTACK_TIME)

# SIGNAL CALLBACKS
func _on_Hurtbox_area_entered(area):
	health -= 1
	hurtbox.create_hit_effect("CA")
	knockback_vec = area.knockback_vec * KNOCKBACK
	hurtSoundEffect.pitch_scale = randf_range(AUDIO_PITCH_MIN, AUDIO_PITCH_MAX)
	hurtSoundEffect.play()
	if knockback_vec.x == 0:
		knockback_vec.x = randf_range(-KNOCKBACK_RAND, KNOCKBACK_RAND)
	elif knockback_vec.y == 0:
		knockback_vec.y = randf_range(-KNOCKBACK_RAND, KNOCKBACK_RAND)
	if health <= 0:
		animationState.travel("Die")
		emit_signal("enemy_dead")
		state = DEAD
		is_dead = false

# ATTACK FUNCTIONS
func _on_AttackZone_body_entered(body):
	state = ATTACK

func _on_AttackZone_body_exited(body):
	state = CHASE

func _on_AttackTimer_timeout():
	attack_ready = true
