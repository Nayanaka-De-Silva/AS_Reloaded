# Godot Input Handling Skill

Input system patterns for Godot 4.x games.

## Input Map Actions

Define actions in **Project > Project Settings > Input Map**:
- `move_left`, `move_right`, `move_up`, `move_down`
- `jump`, `attack`, `interact`
- `pause`, `menu`

## Polling Input (Physics/Process)

```gdscript
func _physics_process(delta: float) -> void:
    # Check if action is held
    if Input.is_action_pressed("move_right"):
        velocity.x = SPEED
    
    # Check if action was just pressed this frame
    if Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_VELOCITY
    
    # Check if action was just released
    if Input.is_action_just_released("attack"):
        end_attack()
    
    # Get axis value (-1 to 1)
    var horizontal := Input.get_axis("move_left", "move_right")
    var vertical := Input.get_axis("move_up", "move_down")
    
    # Get vector for 2D movement
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = direction * SPEED
```

## Event-Based Input (_input and _unhandled_input)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # Keyboard
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_ESCAPE:
            pause_game()
    
    # Mouse button
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            shoot()
    
    # Mouse motion
    if event is InputEventMouseMotion:
        rotate_camera(event.relative)
    
    # Using actions (preferred)
    if event.is_action_pressed("interact"):
        interact_with_object()
        get_viewport().set_input_as_handled()
```

## Input Buffering

```gdscript
var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
    # Update buffer
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time
    else:
        jump_buffer_timer -= delta
    
    # Check buffered input
    if jump_buffer_timer > 0 and is_on_floor():
        perform_jump()
        jump_buffer_timer = 0.0
```

## Mouse Look (First/Third Person)

```gdscript
@export var mouse_sensitivity: float = 0.002

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)
        $Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
        $Camera3D.rotation.x = clamp($Camera3D.rotation.x, -PI/2, PI/2)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

## Best Practices

- Use Input Map actions instead of hardcoded keys
- Use `_unhandled_input` for gameplay, `_input` for UI
- Call `get_viewport().set_input_as_handled()` to stop propagation
- Implement input buffering for responsive controls
- Support both keyboard and gamepad with actions
