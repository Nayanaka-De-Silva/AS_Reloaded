extends Node2D

@export var OFFSET = 0
@export var LOWER_BOUND = 100
@export var ROBBER_LIMIT = 10

const robber_scene = preload("res://Enemies/Robber.tscn")
@onready var timer = $Timer

var screen_size_x = ProjectSettings.get_setting("display/window/size/viewport_width")
var screen_size_y = ProjectSettings.get_setting("display/window/size/viewport_height")
var count = 0

func start_spawn():
	timer.start(2)
	spawn()

func stop_spawn():
	timer.stop()

func spawn():
	var robber = robber_scene.instantiate()
	get_parent().add_child(robber)
	var spawn_position = Vector2.ZERO
	spawn_position.y = randf_range(LOWER_BOUND, screen_size_y)
	spawn_position.x = randf_range(0, 1)
	if spawn_position.x > 0.5:
		spawn_position.x = screen_size_x + OFFSET
	else:
		spawn_position.x = -OFFSET
	robber.position = spawn_position

func _on_Timer_timeout():
	if count < ROBBER_LIMIT:
		spawn()
