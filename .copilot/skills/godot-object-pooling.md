# Godot Object Pooling Skill

Performance optimization through object reuse in Godot 4.x.

## Why Use Object Pooling?

- Avoid performance spikes from frequent `instantiate()` / `queue_free()`
- Reduce memory allocation and garbage collection overhead
- Essential for bullet-hell games, particle effects, spawning enemies

## Basic Pool Implementation

```gdscript
# object_pool.gd
class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 20

var _pool: Array[Node] = []

func _ready() -> void:
    _initialize_pool()

func _initialize_pool() -> void:
    for i in initial_size:
        var obj = pooled_scene.instantiate()
        obj.set_process(false)
        obj.visible = false
        add_child(obj)
        _pool.append(obj)

func get_object() -> Node:
    for obj in _pool:
        if not obj.visible:
            obj.visible = true
            obj.set_process(true)
            return obj
    
    # Pool exhausted - expand dynamically
    var obj = pooled_scene.instantiate()
    add_child(obj)
    _pool.append(obj)
    return obj

func release_object(obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
    # Reset object state here if needed
```

## Bullet Pool Example

```gdscript
# bullet_pool.gd
class_name BulletPool
extends Node

@export var bullet_scene: PackedScene
@export var pool_size: int = 100

var _bullets: Array[Node2D] = []

func _ready() -> void:
    for i in pool_size:
        var bullet = bullet_scene.instantiate()
        bullet.visible = false
        bullet.set_physics_process(false)
        add_child(bullet)
        _bullets.append(bullet)

func spawn_bullet(pos: Vector2, direction: Vector2, speed: float) -> Node2D:
    for bullet in _bullets:
        if not bullet.visible:
            bullet.global_position = pos
            bullet.direction = direction
            bullet.speed = speed
            bullet.visible = true
            bullet.set_physics_process(true)
            return bullet
    
    # Fallback: reuse oldest bullet or expand pool
    push_warning("Bullet pool exhausted!")
    return null

func release_bullet(bullet: Node2D) -> void:
    bullet.visible = false
    bullet.set_physics_process(false)
```

### Pooled Bullet Script
```gdscript
# bullet.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var pool: BulletPool  # Reference to pool for self-release

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    release()

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("take_damage"):
        body.take_damage(10)
    release()

func release() -> void:
    if pool:
        pool.release_bullet(self)
    else:
        visible = false
        set_physics_process(false)
```

## Generic Pool Manager (Autoload)

```gdscript
# pool_manager.gd - Add as Autoload
extends Node

var _pools: Dictionary = {}

func create_pool(pool_name: String, scene: PackedScene, size: int) -> void:
    if pool_name in _pools:
        return
    
    var pool = ObjectPool.new()
    pool.pooled_scene = scene
    pool.initial_size = size
    pool.name = pool_name
    add_child(pool)
    _pools[pool_name] = pool

func get_from_pool(pool_name: String) -> Node:
    if pool_name in _pools:
        return _pools[pool_name].get_object()
    return null

func release_to_pool(pool_name: String, obj: Node) -> void:
    if pool_name in _pools:
        _pools[pool_name].release_object(obj)
```

### Usage
```gdscript
# In _ready() of main scene or loading
func _ready() -> void:
    PoolManager.create_pool("bullets", preload("res://bullet.tscn"), 100)
    PoolManager.create_pool("enemies", preload("res://enemy.tscn"), 30)

# When spawning
func fire_bullet() -> void:
    var bullet = PoolManager.get_from_pool("bullets")
    if bullet:
        bullet.global_position = $Muzzle.global_position
        bullet.direction = (get_global_mouse_position() - bullet.global_position).normalized()
```

## Reset Patterns

Always reset pooled objects when retrieving:

```gdscript
func get_object() -> Node:
    for obj in _pool:
        if not obj.visible:
            _reset_object(obj)
            obj.visible = true
            return obj
    return null

func _reset_object(obj: Node) -> void:
    # Reset common properties
    if obj is Node2D:
        obj.position = Vector2.ZERO
        obj.rotation = 0.0
        obj.scale = Vector2.ONE
    
    # Reset velocity if it's a physics body
    if obj is CharacterBody2D:
        obj.velocity = Vector2.ZERO
    
    # Call custom reset method if available
    if obj.has_method("reset"):
        obj.reset()
```

## Best Practices

- **Pre-allocate** pools during loading screens, not gameplay
- **Spread initialization** across frames if pool is very large:
  ```gdscript
  func _initialize_pool_async() -> void:
      for i in initial_size:
          var obj = pooled_scene.instantiate()
          add_child(obj)
          _pool.append(obj)
          if i % 10 == 0:
              await get_tree().process_frame
  ```
- **Size appropriately**: Test max concurrent usage, add 20% buffer
- **Disable processing**: Set `process_mode` or `set_process(false)` on inactive objects
- **Don't mix**: Either use pooling OR `queue_free()` for an object type, not both
- **Clear pools** between scenes if needed to free memory
