extends Panel

@onready var animationPlayer = $AnimationPlayer

func title_open():
	animationPlayer.play("FadeIn")
