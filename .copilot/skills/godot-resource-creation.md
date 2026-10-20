# Godot Resource Creation Skill

Creating custom resources programmatically in Godot 4.x:

## Defining a Custom Resource

```gdscript
# item_data.gd
class_name ItemData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var value: int = 0
@export var stackable: bool = true
@export var max_stack: int = 99
```

## Resource File Format (.tres)

```
[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/item_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/icons/sword.png" id="2"]

[resource]
script = ExtResource("1")
name = "Iron Sword"
description = "A sturdy iron sword."
icon = ExtResource("2")
value = 100
stackable = false
max_stack = 1
```

## Creating Resources in Code

```gdscript
# Create a new resource instance
var item := ItemData.new()
item.name = "Health Potion"
item.value = 50

# Save resource to file
ResourceSaver.save(item, "res://data/items/health_potion.tres")

# Load resource from file
var loaded_item := load("res://data/items/health_potion.tres") as ItemData
```

## Using Resources in Exports

```gdscript
# In a script that uses the resource
@export var weapon_data: ItemData
@export var inventory: Array[ItemData] = []

func _ready() -> void:
    if weapon_data:
        print("Equipped: ", weapon_data.name)
```

## Sub-Resources

```gdscript
# Resource containing other resources
class_name CharacterStats
extends Resource

@export var base_stats: Resource  # Another custom resource
@export var abilities: Array[Resource] = []
```

## Resource Preloading

```gdscript
# Preload for compile-time loading (faster)
const SWORD_DATA := preload("res://data/items/sword.tres")

# Load for runtime loading
var item_data := load("res://data/items/" + item_name + ".tres")
```
