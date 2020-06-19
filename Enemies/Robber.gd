extends KinematicBody2D

# EXTERNAL VARIABLES
export var KNOCKBACK_FRICTION = 300
export var KNOCKBACK = 100
export var MAX_SPEED = 80
export var ACCELERATION = 300
export var FRICTION = 300
export var ATTACK_TIME = 2.5
export var health = 2

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
var can_move

# ATTACHED NODES
onready var detectionZone = $DetectionZone
onready var detectionCircle = $DetectionZone/DetectionCircle
onready var attackTimer = $AttackTimer
onready var hurtbox = $Hurtbox
onready var punchHitbox = $Hitpivot/PunchHitbox
onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")

# SIGNALS
signal enemy_dead

# BASIC FUNCTIONS
func _ready():
	animationTree.active = true
	attackTimer.start(ATTACK_TIME)
	detectionCircle.disabled = false
	add_to_group("Enemies")

func _physics_process(delta):
	can_move = Controls.can_move
	knockback_vec = knockback_vec.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	knockback_vec = move_and_slide(knockback_vec)
	var player = detectionZone.target
	if is_dead:
		state = DEAD
	if can_move:
		match state:
			IDLE:
				animationState.travel("Idle")
				Idle_state(delta)
			CHASE:
				if player != null:
					Chase_state(player, delta)
				else:
					state = IDLE
			ATTACK:
				Attack_state(delta)
			DEAD:
				velocity = Vector2.ZERO
				is_dead = true
				state = DEAD
	else:
		state = IDLE
	
	velocity = move_and_slide(velocity)

func find_target():
	if detectionZone.target_found():
		state = CHASE


# STATE HANDLING FUNCTIONS
func Idle_state(delta):
	stop(delta)
	find_target()

func Chase_state(target, delta):
	var direction = global_position.direction_to(target.global_position).normalized()
	punchHitbox.knockback_vec = direction
	direction_change(direction)
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	animationState.travel("Run")

func Attack_state(delta):
	# Attack state code
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	if attack_ready:
		animationState.travel("Attack")
		attack_ready = false
		attackTimer.start(ATTACK_TIME)

func direction_change(input_vector):
	animationTree.set("parameters/Idle/blend_position", input_vector)
	animationTree.set("parameters/Run/blend_position", input_vector)
	animationTree.set("parameters/Attack/blend_position", input_vector)
	animationTree.set("parameters/Die/blend_position", input_vector)

func stop(delta):
	animationState.travel("Idle")
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func attack_animation_finished():
	animationState.travel("Idle")

func _on_Hurtbox_area_entered(area):
	health -= 1
	hurtbox.create_hit_effect("CA")
	knockback_vec = area.knockback_vec * KNOCKBACK
	if health <= 0:
		animationState.travel("Die")
		state = DEAD

# ATTACK FUNCTIONS
func _on_AttackZone_body_entered(body):
	if is_dead:
		state = DEAD
	else:
		animationState.travel("Idle")
		state = ATTACK

func _on_AttackZone_body_exited(body):
	if is_dead:
		emit_signal("enemy_dead")
		state = DEAD
	else:
		state = CHASE

func _on_AttackTimer_timeout():
	attack_ready = true
