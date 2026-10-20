# Godot Character Setup Skill

CharacterBody2D implementation pattern for Godot 4.x:

## Scene Structure

```
CharacterBody2D (root)
├── CollisionShape2D
├── Sprite2D or AnimatedSprite2D
└── (optional) Camera2D
```

## Controller Script

```gdscript
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
    # Add gravity
    if not is_on_floor():
        velocity.y += gravity * delta

    # Handle jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Get input direction
    var direction := Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
```

## Key Points

- Use `CharacterBody2D` as root node (not KinematicBody2D)
- Implement `_physics_process(delta)` method
- Use `move_and_slide()` for movement (returns nothing in Godot 4)
- Store velocity as built-in property (no need to declare)
- Handle delta time correctly: `velocity.y += gravity * delta`
- Use `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()` for collision checks
- Get gravity from ProjectSettings for consistency with RigidBody2D
