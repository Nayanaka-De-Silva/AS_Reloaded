extends Area2D

const POW_CA = preload("res://Effects/Visual_Effects/POW_Effect.tscn")
const BAM_CA = preload("res://Effects/Visual_Effects/BAM_Effect.tscn")
const BIFF_CA = preload("res://Effects/Visual_Effects/BIFF_Effect.tscn")
const POW_enemy = preload("res://Effects/Visual_Effects/POW_Effect_Enemy.tscn")
const BAM_enemy = preload("res://Effects/Visual_Effects/BAM_Effect_Enemy.tscn")
const BIFF_enemy = preload("res://Effects/Visual_Effects/BIFF_Effect_Enemy.tscn")

const CA_effects = [POW_CA, BAM_CA, BIFF_CA]
const Enemy_effects = [POW_enemy, BAM_enemy, BIFF_enemy]

export var rand_x_max = 10
export var rand_x_min = -10
export var rand_y_max = 10
export var rand_y_min = -10

func create_hit_effect(source):
	var effect = null
	if source == "CA":
		CA_effects.shuffle()
		effect = CA_effects[0].instance()
	elif source == "Enemy":
		Enemy_effects.shuffle()
		effect = Enemy_effects[0].instance()
	var main = get_tree().current_scene
	main.add_child(effect)
	var newPosition = Vector2.ZERO
	newPosition.x = global_position.x + rand_range(rand_x_min, rand_x_max)
	newPosition.y = global_position.y + rand_range(rand_y_min, rand_y_max)
	effect.global_position = newPosition
