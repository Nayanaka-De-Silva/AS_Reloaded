# Godot Navigation & Pathfinding Skill

NavigationAgent2D/3D patterns for AI movement in Godot 4.x.

## Navigation Setup

### 2D Navigation
```
NavigationRegion2D (add NavigationPolygon)
  └── CollisionPolygon2D (define walkable area)

CharacterBody2D (your enemy/NPC)
  └── NavigationAgent2D
```

### 3D Navigation
```
NavigationRegion3D (bake NavigationMesh)
  └── MeshInstance3D (level geometry)

CharacterBody3D (your enemy/NPC)
  └── NavigationAgent3D
```

## Basic Path Following

### 2D Character with NavigationAgent2D
```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func set_target(target_position: Vector2) -> void:
    nav_agent.target_position = target_position

func _physics_process(delta: float) -> void:
    if nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()
```

### 3D Character with NavigationAgent3D
```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func set_target(target_position: Vector3) -> void:
    nav_agent.target_position = target_position

func _physics_process(delta: float) -> void:
    if nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()
    
    # Face movement direction
    if direction != Vector3.ZERO:
        look_at(global_position + direction)
```

## Patrol Pattern
```gdscript
extends CharacterBody2D

@export var patrol_points: Array[Marker2D] = []
@export var speed: float = 100.0
@export var wait_time: float = 2.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var current_patrol_index: int = 0
var waiting: bool = false

func _ready() -> void:
    if patrol_points.size() > 0:
        _go_to_next_patrol_point()

func _physics_process(delta: float) -> void:
    if waiting or nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()

func _go_to_next_patrol_point() -> void:
    nav_agent.target_position = patrol_points[current_patrol_index].global_position

func _on_navigation_agent_2d_navigation_finished() -> void:
    waiting = true
    await get_tree().create_timer(wait_time).timeout
    current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
    _go_to_next_patrol_point()
    waiting = false
```

## Chase Player with Update Interval
```gdscript
extends CharacterBody2D

@export var speed: float = 150.0
@export var path_update_interval: float = 0.5

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D = null

func _ready() -> void:
    # Update path periodically (not every frame)
    var timer = Timer.new()
    timer.wait_time = path_update_interval
    timer.timeout.connect(_update_path)
    add_child(timer)
    timer.start()

func set_chase_target(new_target: Node2D) -> void:
    target = new_target

func _update_path() -> void:
    if target:
        nav_agent.target_position = target.global_position

func _physics_process(delta: float) -> void:
    if not target or nav_agent.is_navigation_finished():
        velocity = Vector2.ZERO
        return
    
    var next_pos = nav_agent.get_next_path_position()
    velocity = (next_pos - global_position).normalized() * speed
    move_and_slide()
```

## NavigationAgent Properties

| Property | Purpose |
|----------|---------|
| `path_desired_distance` | Distance to waypoint before moving to next |
| `target_desired_distance` | Distance to target to consider "arrived" |
| `navigation_layers` | Which navigation meshes to use |
| `avoidance_enabled` | Enable obstacle avoidance |
| `max_speed` | For avoidance calculations |

## Dynamic Obstacles
```gdscript
# Add NavigationObstacle2D as child of moving obstacles
# The navigation system will route around them

# For static obstacles, bake them into the NavigationPolygon/Mesh
```

## Best Practices

- Update target_position periodically, not every frame (use timer)
- Check `is_navigation_finished()` before moving
- Use `navigation_layers` to separate flying vs ground navigation
- Enable avoidance for multiple agents moving simultaneously
- For smooth rotation, lerp instead of snapping:
  ```gdscript
  rotation = lerp_angle(rotation, direction.angle(), delta * 10.0)
  ```
