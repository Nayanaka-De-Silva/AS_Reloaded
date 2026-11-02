extends Control

@onready var speaker = $Panel/Speaker
@onready var content = $Panel/Content
@onready var timer = $TextTimer

var text_position
var Current_text
var text_pos = 0

signal text_started
signal text_ended

func _ready():
	timer.stop()

func speak(character, text):
	text_pos = 0
	Current_text = text
	speaker.text = character + ":"
	content.text = text[text_pos]
	timer.start()
	emit_signal("text_started")

func text_update():
	if text_pos < len(Current_text):
		content.text += Current_text[text_pos]
	else:
		timer.stop()
		emit_signal("text_ended")

func _on_TextTimer_timeout():
	text_pos += 1
	text_update()
