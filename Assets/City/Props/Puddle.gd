extends Area2D

@onready var animation = $AnimatedSprite2D

func _on_Puddle_body_entered(body):
	animation.play()

func _on_AnimatedSprite_animation_finished():
	animation.frame = 0
	animation.stop()
