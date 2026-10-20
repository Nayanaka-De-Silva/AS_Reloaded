# Godot Scene Creation Skill

When creating a new Godot scene:

1. **Specify root node type explicitly**
   - Use Node2D for 2D scenes, Node3D for 3D scenes
   - Use Control for UI scenes
   - Use specific types like CharacterBody2D when appropriate

2. **Use only Godot 4.x node names** (no Godot 3 equivalents)
   - CharacterBody2D (not KinematicBody2D)
   - CharacterBody3D (not KinematicBody)
   - AnimationPlayer, AnimationTree
   - Use @onready and @export annotations

3. **Provide complete .tscn structure** with all child nodes and properties
   ```
   [gd_scene load_steps=2 format=3]
   
   [ext_resource type="Script" path="res://path/to/script.gd" id="1"]
   
   [node name="Root" type="Node2D"]
   script = ExtResource("1")
   
   [node name="Child" type="Sprite2D" parent="."]
   position = Vector2(100, 100)
   ```

4. **Provide attached GDScript separately** in a .gd file
   - Use class_name for reusable scripts
   - Follow GDScript style guide
   - Use type hints for all variables and functions

5. **Connect all signals using `node.signal.connect(target_method)` syntax**
   ```gdscript
   func _ready() -> void:
       $Button.pressed.connect(_on_button_pressed)
   ```

6. **Use `@export` and `@onready` decorators** for exposed properties
   ```gdscript
   @export var speed: float = 100.0
   @onready var sprite: Sprite2D = $Sprite2D
   ```
