# Godot Signal Connection Skill

Programmatic signal binding patterns for Godot 4.x:

## Connecting Signals in Code

```gdscript
func _ready() -> void:
    # Connect to a signal with a method
    $Button.pressed.connect(_on_button_pressed)
    
    # Connect with arguments using bind()
    $Button.pressed.connect(_on_button_pressed.bind("extra_arg"))
    
    # Connect with flags
    $Timer.timeout.connect(_on_timer_timeout, CONNECT_ONE_SHOT)
```

## Defining Custom Signals

```gdscript
# Signal without parameters
signal died

# Signal with parameters (use type hints)
signal health_changed(new_health: int)
signal damage_taken(amount: int, source: Node)

# Emitting signals
func take_damage(amount: int, source: Node) -> void:
    health -= amount
    damage_taken.emit(amount, source)
    health_changed.emit(health)
    if health <= 0:
        died.emit()
```

## Awaiting Signals

```gdscript
# Wait for a timer
await get_tree().create_timer(1.0).timeout

# Wait for animation to finish
await $AnimationPlayer.animation_finished

# Wait for custom signal
await some_node.my_custom_signal
```

## Connection in Scene Files (.tscn)

```
[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
[connection signal="body_entered" from="Area2D" to="." method="_on_area_body_entered"]
```

## Disconnecting Signals

```gdscript
# Disconnect a specific connection
$Button.pressed.disconnect(_on_button_pressed)

# Check if connected before disconnecting
if $Button.pressed.is_connected(_on_button_pressed):
    $Button.pressed.disconnect(_on_button_pressed)
```

## Lambda/Callable Connections

```gdscript
# Using lambda for simple inline handlers
$Button.pressed.connect(func(): print("Button pressed!"))

# Using Callable for dynamic connections
var callable := Callable(self, "_on_button_pressed")
$Button.pressed.connect(callable)
```
