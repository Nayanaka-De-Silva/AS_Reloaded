extends Control

onready var speech = $Speech_Text

var line = 1
var curr_script = null

signal dialog_finished

func _process(delta):
	if Input.is_action_just_pressed("Attack") and not Controls.can_move:
		if line < len(curr_script):
			line += 1
			script()
		else:
			emit_signal("dialog_finished")
			curr_script = null

func script():
	speech.speak(curr_script[line][0], curr_script[line][1])

func load_script(new_script):
	line = 1
	curr_script = new_script
	script()
