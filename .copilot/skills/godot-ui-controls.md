# Godot UI Controls Skill

Building user interfaces with Control nodes in Godot 4.x.

## UI Node Hierarchy

```
CanvasLayer (for UI overlay)
  └── Control (root UI container)
       ├── MarginContainer
       │    └── VBoxContainer
       │         ├── Label
       │         ├── Button
       │         └── HBoxContainer
       └── Panel
```

## Container Types

| Container | Purpose |
|-----------|---------|
| VBoxContainer | Vertical layout |
| HBoxContainer | Horizontal layout |
| GridContainer | Grid layout |
| MarginContainer | Add margins around content |
| CenterContainer | Center child in available space |
| PanelContainer | Visual panel with child |
| ScrollContainer | Scrollable area |

## Anchors and Size Flags

```gdscript
# Full screen UI
control.anchor_left = 0.0
control.anchor_top = 0.0
control.anchor_right = 1.0
control.anchor_bottom = 1.0

# Size flags for containers
control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
```

## Creating UI in Code

```gdscript
func create_menu() -> Control:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_CENTER)
    root.add_child(vbox)
    
    var title := Label.new()
    title.text = "Main Menu"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var play_btn := Button.new()
    play_btn.text = "Play"
    play_btn.pressed.connect(_on_play_pressed)
    vbox.add_child(play_btn)
    
    return root
```

## Theme Styling

```gdscript
# Apply theme to all children
var theme := Theme.new()
theme.set_font_size("font_size", "Button", 24)
theme.set_color("font_color", "Button", Color.WHITE)
control.theme = theme
```

## Common UI Patterns

### Health Bar
```gdscript
@onready var health_bar: ProgressBar = $HealthBar

func update_health(current: int, maximum: int) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
```

### Dialog Box
```gdscript
func show_dialog(text: String) -> void:
    $DialogPanel.visible = true
    $DialogPanel/Label.text = text
    await get_tree().create_timer(2.0).timeout
    $DialogPanel.visible = false
```

## Best Practices

- Use containers instead of manual positioning
- Set anchors for responsive layouts
- Use themes for consistent styling
- Keep UI logic separate from game logic
- Use CanvasLayer to keep UI above game elements
