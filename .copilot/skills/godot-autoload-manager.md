# Godot Autoload Manager Skill

Singleton pattern using Godot 4's Autoload system for global managers.

## Creating a Game Manager

**GameManager.gd:**
```gdscript
extends Node

# Signals for state changes
signal score_changed(new_score: int)
signal game_paused(is_paused: bool)
signal game_over

# Game state
var score: int = 0:
    set(value):
        score = value
        score_changed.emit(score)

var is_paused: bool = false
var current_level: int = 1

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused

func add_score(points: int) -> void:
    score += points

func pause_game() -> void:
    is_paused = true
    get_tree().paused = true
    game_paused.emit(true)

func resume_game() -> void:
    is_paused = false
    get_tree().paused = false
    game_paused.emit(false)

func reset_game() -> void:
    score = 0
    current_level = 1
    is_paused = false
```

## Registering as Autoload

1. Go to **Project > Project Settings > Autoload**
2. Browse for your script (e.g., `GameManager.gd`)
3. Set the Node Name (e.g., `GameManager`)
4. Click **Add**

## Accessing the Singleton

```gdscript
# From any script in your project
GameManager.add_score(100)
print(GameManager.score)

# Connect to signals
GameManager.score_changed.connect(_on_score_changed)
```

## Common Manager Types

### AudioManager.gd
```gdscript
extends Node

var music_volume: float = 1.0
var sfx_volume: float = 1.0

func play_music(stream: AudioStream) -> void:
    # Implementation
    pass

func play_sfx(stream: AudioStream) -> void:
    # Implementation
    pass
```

### SaveManager.gd
```gdscript
extends Node

const SAVE_PATH := "user://savegame.json"

func save_game(data: Dictionary) -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    return JSON.parse_string(file.get_as_text())
```

## Best Practices

- Keep singletons focused on one responsibility
- Use signals for decoupled communication
- Set `process_mode = PROCESS_MODE_ALWAYS` for managers that need to run during pause
- Avoid putting game logic in managers - they should coordinate, not implement
- Consider using an EventBus singleton for global event handling
