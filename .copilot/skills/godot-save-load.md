# Godot Save/Load System Skill

Implementing game save and load functionality in Godot 4.x.

## JSON-Based Save System

### SaveManager.gd (Autoload)
```gdscript
extends Node

const SAVE_PATH := "user://savegame.json"

signal game_saved
signal game_loaded

func save_game(data: Dictionary) -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not open save file: %s" % FileAccess.get_open_error())
        return false
    
    var json_string := JSON.stringify(data, "\t")  # Pretty print
    file.store_string(json_string)
    file.close()
    game_saved.emit()
    return true

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    
    var json_string := file.get_as_text()
    file.close()
    
    var data = JSON.parse_string(json_string)
    if data == null:
        push_error("Failed to parse save file")
        return {}
    
    game_loaded.emit()
    return data

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
    if has_save():
        DirAccess.remove_absolute(SAVE_PATH)
```

### Usage Example
```gdscript
# Saving
func _on_save_pressed() -> void:
    var save_data := {
        "version": 1,
        "player": {
            "position": {"x": player.position.x, "y": player.position.y},
            "health": player.health,
            "inventory": player.inventory
        },
        "level": current_level,
        "playtime": playtime_seconds
    }
    SaveManager.save_game(save_data)

# Loading
func _on_load_pressed() -> void:
    var data := SaveManager.load_game()
    if data.is_empty():
        print("No save found")
        return
    
    player.position = Vector2(data.player.position.x, data.player.position.y)
    player.health = data.player.health
    current_level = data.level
```

## Resource-Based Save System

### PlayerData.gd (Custom Resource)
```gdscript
extends Resource
class_name PlayerData

@export var player_name: String = ""
@export var health: int = 100
@export var position: Vector2 = Vector2.ZERO
@export var inventory: Array[String] = []
```

### Saving/Loading Resources
```gdscript
const SAVE_PATH := "user://player_data.tres"

func save_player_data(data: PlayerData) -> void:
    var error := ResourceSaver.save(data, SAVE_PATH)
    if error != OK:
        push_error("Failed to save: %s" % error)

func load_player_data() -> PlayerData:
    if ResourceLoader.exists(SAVE_PATH):
        return ResourceLoader.load(SAVE_PATH) as PlayerData
    return PlayerData.new()  # Return default
```

## Best Practices

- Always save to `user://` (writable on all platforms)
- Include a version number for save format migrations
- Handle missing or corrupted files gracefully
- Use JSON for human-readable saves, Resources for complex data
- Consider encryption for sensitive data
- Implement autosave with a timer
