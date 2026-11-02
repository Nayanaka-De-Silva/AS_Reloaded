extends GutTest

const ROBBER_SCENE_PATH: String = "res://Assets/Characters/Robber/Robber.tscn"
const PHYSICS_STEP_SECONDS: float = 0.1

var robber: CharacterBody2D


func before_each() -> void:
	var robber_scene: PackedScene = load(ROBBER_SCENE_PATH)
	robber = robber_scene.instantiate()
	add_child_autofree(robber)
	Controls.can_move = true


func _chase_target_to_the_right() -> void:
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	target.global_position = robber.global_position + Vector2(1000.0, 0.0)
	robber.state = robber.CHASE
	var steps_to_max_speed: int = ceili(float(robber.MAX_SPEED) / (robber.ACCELERATION * PHYSICS_STEP_SECONDS))
	for _step: int in steps_to_max_speed:
		robber.Chase_state(target, PHYSICS_STEP_SECONDS)


func test_scene_builds_with_its_script_attached() -> void:
	assert_true(robber.has_method("Chase_state"), "Robber.gd should parse and attach")


func test_chasing_accelerates_to_max_speed() -> void:
	_chase_target_to_the_right()
	assert_almost_eq(robber.walk_velocity.x, float(robber.MAX_SPEED), 0.01)


func test_knockback_does_not_overwrite_walking_speed() -> void:
	_chase_target_to_the_right()
	robber.knockback_vec = Vector2.LEFT * 50.0
	robber.is_dead = true
	robber._physics_process(PHYSICS_STEP_SECONDS)
	assert_almost_eq(robber.walk_velocity.x, float(robber.MAX_SPEED), 0.01)


func test_stopping_decelerates_walking_speed() -> void:
	_chase_target_to_the_right()
	robber.stop(PHYSICS_STEP_SECONDS)
	assert_lt(robber.walk_velocity.x, float(robber.MAX_SPEED))
