extends Panel

@onready var continueAnimation = $AnimationPlayer
@onready var continueText = $ContinueText

func _ready():
	pass # Replace with function body.

func start_animation():
	continueAnimation.play("Blink")
	continueText.visible = true

func stop_animation():
	continueAnimation.stop(true)
	continueText.visible = false
