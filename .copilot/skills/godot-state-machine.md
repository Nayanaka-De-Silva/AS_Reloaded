# Godot State Machine Skill

Finite State Machine (FSM) patterns for Godot 4.x game AI and player controllers.

## Simple State Machine (Enum-based)

For simple cases with few states:

```gdscript
extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING }
var current_state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _state_idle(delta)
        State.RUNNING:
            _state_running(delta)
        State.JUMPING:
            _state_jumping(delta)
        State.FALLING:
            _state_falling(delta)

func _state_idle(_delta: float) -> void:
    if Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left"):
        current_state = State.RUNNING
    if Input.is_action_just_pressed("jump") and is_on_floor():
        current_state = State.JUMPING

func _state_running(_delta: float) -> void:
    if not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"):
        current_state = State.IDLE

func _state_jumping(_delta: float) -> void:
    if velocity.y > 0:
        current_state = State.FALLING

func _state_falling(_delta: float) -> void:
    if is_on_floor():
        current_state = State.IDLE
```

## Node-Based State Machine (Scalable)

For complex AI or characters, use separate State nodes:

**Directory Structure:**
```
Player.tscn
  └── StateMachine (Node)
       ├── IdleState (Node)
       ├── RunState (Node)
       └── JumpState (Node)
```

**StateMachine.gd:**
```gdscript
extends Node
class_name StateMachine

var current_state: State = null
var states: Dictionary = {}

@export var initial_state: NodePath

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name] = child
            child.state_machine = self
    
    if initial_state:
        current_state = get_node(initial_state)
        current_state.enter()

func change_state(new_state_name: String) -> void:
    if current_state:
        current_state.exit()
    current_state = states.get(new_state_name)
    if current_state:
        current_state.enter()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)
```

**State.gd (Base Class):**
```gdscript
extends Node
class_name State

var state_machine: StateMachine = null

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass
```

**IdleState.gd (Example):**
```gdscript
extends State

func enter() -> void:
    # Play idle animation
    pass

func physics_update(_delta: float) -> void:
    if Input.is_action_pressed("move_right"):
        state_machine.change_state("RunState")
    if Input.is_action_just_pressed("jump"):
        state_machine.change_state("JumpState")
```

## Best Practices

- Use enum-based FSM for simple cases (< 5 states)
- Use node-based FSM for complex AI or extensible systems
- Always implement `enter()` and `exit()` for setup/cleanup
- Keep state logic isolated - states should not know about each other's internals
- Use signals for state change notifications if needed
