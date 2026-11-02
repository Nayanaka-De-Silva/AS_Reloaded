extends Control

@export var TEXT_SLIDE = 50

@onready var Speech = $Speech_Text
@onready var BottomBar = $BottomBar

var line = 0
var curr_script = null
var slide = false
var BottomBar_pos
var BottomBar_size
var TextPanel_size

signal dialog_finished

func _ready():
	BottomBar_pos = BottomBar.position.y
	BottomBar_size = BottomBar.size.y
	TextPanel_size = Speech.size.y

func _process(delta):
	slide_text_panel(delta)

func _input(event):
	if event.is_action_pressed("Next") and !Controls.can_move:
		if line+1 < len(curr_script):
			line += 1
			script()
		else:
			slide = false
			emit_signal("dialog_finished")
			curr_script = null

func script():
	Speech.speak(curr_script[line][0], curr_script[line][1])

func load_script(new_script):
	slide = true
	line = 0
	curr_script = new_script
	script()

func slide_text_panel(delta):
	if slide:
		Speech.position = Speech.position.move_toward(Vector2.ZERO, TEXT_SLIDE * delta)
		BottomBar.position = BottomBar.position.move_toward(Vector2(0, BottomBar_pos-BottomBar_size), TEXT_SLIDE * delta)
	else:
		Speech.position = Speech.position.move_toward(Vector2(0, -TextPanel_size), TEXT_SLIDE * delta)
		BottomBar.position = BottomBar.position.move_toward(Vector2(0, BottomBar_pos), TEXT_SLIDE * delta)


func _on_Speech_Text_text_ended():
	BottomBar.start_animation()


func _on_Speech_Text_text_started():
	BottomBar.stop_animation()
