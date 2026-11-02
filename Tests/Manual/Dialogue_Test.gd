extends Node2D

@onready var dialogue = $Dialog

var script_1 = [
	["Captain Awesome", "Hold it right there, evil scum!"],
	["Robber", "Wait what? Who are you?"],
	["Captain Awesome", "I am the light against the darkness."],
	["Captain Awesome", "The bringer of hope and justice."],
	["Captain Awesome", "I am....CAPTAIN AWESOME"]
]

func _ready():
	Controls.can_move = false
	dialogue.load_script(script_1)

func _on_Dialog_dialog_finished():
	print("Dialogue finished")
