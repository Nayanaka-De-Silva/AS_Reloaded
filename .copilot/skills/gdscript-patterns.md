# GDScript 2.0 Patterns Skill

## Type Hints

Always use type hints for clarity:

```gdscript
var health: int = 100
var player_name: String = "Hero"
var items: Array[Item] = []
var stats: Dictionary = {}

func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)
```

## Annotations

```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@export var speed: float = 100.0
@export_range(0, 100) var health: int = 100
@export_group("Movement")
@export var jump_height: float = 200.0
```

## Signals

```gdscript
signal health_changed(new_health: int)
signal died

func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health)
    if health <= 0:
        died.emit()
```

## Awaiting Signals

```gdscript
await get_tree().create_timer(1.0).timeout
await animation_player.animation_finished
```

## Super Calls

```gdscript
func _ready() -> void:
    super._ready()  # Call parent implementation
    # Your code here
```

## Static Typing

```gdscript
# Prefer static typing for better performance and error checking
var enemies: Array[Enemy] = []
var player: Player = null

func get_closest_enemy() -> Enemy:
    # Return type is explicit
    return enemies[0] if enemies.size() > 0 else null
```
