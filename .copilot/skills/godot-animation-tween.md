# Godot Animation & Tween Skill

AnimationPlayer and Tween patterns for Godot 4.x.

## When to Use Each

| System | Best For |
|--------|----------|
| AnimationPlayer | Hand-crafted sequences, character animations, cinematics |
| Tween | Procedural/dynamic animations, runtime-determined values |

## AnimationPlayer Patterns

### Method Call Tracks
Synchronize game logic with animation keyframes:

```gdscript
# Called from AnimationPlayer Method Call Track
func enable_hitbox() -> void:
    $Hitbox.disabled = false

func disable_hitbox() -> void:
    $Hitbox.disabled = true

func spawn_particle_effect() -> void:
    var particles = preload("res://effects/hit_spark.tscn").instantiate()
    add_child(particles)
```

### Playing Animations
```gdscript
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func play_attack() -> void:
    anim_player.play("attack")
    await anim_player.animation_finished
    anim_player.play("idle")

# Queue animations
func play_combo() -> void:
    anim_player.play("attack_1")
    anim_player.queue("attack_2")
    anim_player.queue("idle")
```

## Tween Patterns

### Basic Tween Usage
```gdscript
func move_to(target_pos: Vector2) -> void:
    var tween = create_tween()
    tween.tween_property(self, "position", target_pos, 0.5)

# With easing
func bounce_in() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(self, "scale", Vector2.ONE, 0.2)\
        .set_trans(Tween.TRANS_BOUNCE)\
        .set_ease(Tween.EASE_OUT)
```

### Tween Transitions & Easing
```gdscript
# Common transitions
Tween.TRANS_LINEAR   # Constant speed
Tween.TRANS_SINE     # Smooth, natural motion
Tween.TRANS_BOUNCE   # Bouncy effect
Tween.TRANS_ELASTIC  # Springy overshoot
Tween.TRANS_BACK     # Slight overshoot

# Ease modes
Tween.EASE_IN        # Start slow
Tween.EASE_OUT       # End slow
Tween.EASE_IN_OUT    # Slow at both ends
```

### Chaining & Parallel Tweens
```gdscript
func animate_ui_panel() -> void:
    var tween = create_tween()
    # Sequential (one after another)
    tween.tween_property($Panel, "modulate:a", 1.0, 0.3)
    tween.tween_property($Panel, "position", Vector2(100, 100), 0.5)
    
    # Parallel (at the same time)
    tween.set_parallel(true)
    tween.tween_property($Panel, "scale", Vector2.ONE, 0.3)
    tween.tween_property($Panel, "rotation", 0.0, 0.3)
```

### Fade Effects
```gdscript
func fade_in(node: CanvasItem, duration: float = 0.5) -> void:
    node.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(node, "modulate:a", 1.0, duration)

func fade_out_and_free(node: Node, duration: float = 0.5) -> void:
    var tween = create_tween()
    tween.tween_property(node, "modulate:a", 0.0, duration)
    tween.tween_callback(node.queue_free)
```

### Screen Shake
```gdscript
func screen_shake(intensity: float = 10.0, duration: float = 0.2) -> void:
    var camera = get_viewport().get_camera_2d()
    var original_offset = camera.offset
    var tween = create_tween()
    
    for i in range(int(duration * 60)):
        var offset = Vector2(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        tween.tween_property(camera, "offset", offset, 1.0/60.0)
    
    tween.tween_property(camera, "offset", original_offset, 0.05)
```

## Best Practices

- Use AnimationPlayer for predefined, hand-authored sequences
- Use Tween for dynamic values known only at runtime
- Always `await tween.finished` if you need to sequence actions
- Kill existing tweens before starting new ones on the same property:
  ```gdscript
  if tween and tween.is_valid():
      tween.kill()
  tween = create_tween()
  ```
- Use `set_loops()` for repeating animations
- Combine AnimationPlayer for main animations with Tweens for dynamic overlays
