# AGENTS.md - AI Coding Agent Instructions

> This file provides instructions for AI coding agents (GitHub Copilot, Claude, GPT, etc.) working on this Godot project.

<!-- setup-godot-agentic:godot-config:start -->
## Godot Project Configuration

```
PROJECT_GODOT_VERSION=4.5
GDSCRIPT_SYNTAX=GDScript 2.0
PREFERRED_NODES=CharacterBody2D, CharacterBody3D, StaticBody2D, StaticBody3D
DEPRECATED_NODES=KinematicBody2D, KinematicBody, StaticBody (use 2D/3D variants)
DOCS_VERSION=4.5
```

### Coding Rules

- Use only GDScript 2.0 syntax
- Never use Godot 3.x APIs
- Use `@onready` instead of `onready`
- Use `@export` instead of `export`
- Always verify signals and properties against official 4.5 docs
- Reference local documentation in `.docs/godot-4.5/` when available
<!-- setup-godot-agentic:godot-config:end -->

## Node Type Reference

| Godot 3.x (Don't Use) | Godot 4.x (Use This) |
|----------------------|---------------------|
| KinematicBody2D | CharacterBody2D |
| KinematicBody | CharacterBody3D |
| Spatial | Node3D |
| Position2D | Marker2D |
| Position3D | Marker3D |
| YSort | Node2D with y_sort_enabled |
| VisibilityNotifier2D | VisibleOnScreenNotifier2D |

## Code Style

- Follow [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- Use type hints for all variables and function parameters
- Use meaningful variable and function names
- Keep functions focused and under 30 lines when possible

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `Assets/` | Game content by feature: scenes, their scripts, art, audio, fonts |
| `Components/` | Reusable gameplay building blocks (hitboxes, stats, camera) |
| `Effects/` | Visual effects |
| `Globals/` | Autoload singletons |
| `Resources/` | Shared resource files |
| `Tests/` | `Unit/` and `Integration/` GUT tests, `Manual/` test scenes |
| `.copilot/skills/` | AI skill templates |
| `.docs/godot-4.5/` | Offline Godot documentation |

## Before Committing Code

1. Run `./validate-godot.sh` to check GDScript syntax
2. Ensure no Godot 3.x APIs are used (if this is a Godot 4 project)
3. Verify signal connections use the new syntax: `signal.connect(method)`

## Available Resources

- **Skill Templates**: Check `.copilot/skills/` for patterns on scene creation, character controllers, signals, and resources
- **Offline Docs**: Search `.docs/godot-4.5/` for API reference (use grep/ripgrep)
- **Validation**: Run `./validate-godot.sh` for syntax checking

## Quick Reference

### Signal Connection (Godot 4)
```gdscript
# Connect in code
$Button.pressed.connect(_on_button_pressed)

# With arguments
$Timer.timeout.connect(_on_timeout.bind(extra_arg))
```

### Export Variables (Godot 4)
```gdscript
@export var speed: float = 100.0
@export_range(0, 100) var health: int = 100
@onready var sprite: Sprite2D = $Sprite2D
```

### Physics Process
```gdscript
func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta
    move_and_slide()
```
