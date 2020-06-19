extends Node2D

onready var dialog = $CanvasLayer/Dialog
onready var CA=$YSort/Capt_Awesome
onready var Robber_1 = $YSort/Robber
onready var timer = $Event_Timer
onready var Robber_spawner = $YSort/Robber_spawner

var current_event = -1
var event_flag = true
var movement_flag = false

var script_0 = {
	1: ["Robber", "Hehehe...Look at all this money."],
	2: ["Robber", "HAHAHA"],
	3: ["Captain Awesome", "HOLD IT RIGHT THERE, EVIL SCUM!"]
}
var script_1 = {
	1: ["Robber", "Who the hell are you?"],
	2: ["Captain Awesome", "I'm the light against the darkness."],
	3: ["Captain Awesome", "The bringer of hope and justice."],
	4: ["Captain Awesome", "I am..."],
	5: ["Captain Awesome", "CAPTAIN AWESOME!"],
	6: ["Robber", "...really?"],
	7: ["Captain Awesome", "...I mean...yeah"],
	8: ["Robber", "Heh, let's see how awesome you are after I beat you up."],
}
var script_2 = {
	1: ["Robber", "OW FUCK"],
	2: ["Robber", "....you think you're so slick?"],
	3: ["Robber", "Well, let's see how well you do against my posse."],
	4: ["Robber", "YOLOLOLOLOLOLOLOLOLOLOLOLOLOL"],
	5: ["Captain Awesome", "Aw crap"]
}
var script_3 = {
	1: ["Robber", "HAHAHA, you fucking loser"],
	2: ["Captain Awesome", "...ooo...ouh..."],
	3: ["Robber", "Come on boys, let's leave this loser"]
}

func _physics_process(delta):
	if event_flag:
		current_event += 1
	event(delta)

func event(delta):
	match current_event:
		1:
			# Robber Intro
			Controls.can_move = false
			dialog.visible = true
			Robber_1.direction_change(Vector2(-1, 0).normalized())
			if event_flag:
				dialog.load_script(script_0)
		2: 
			# Captain Awesome Intro
			if event_flag: 
				dialog.load_script(script_1)
				start_timer(1.5)
			Robber_1.direction_change(Vector2(1, 0).normalized())
			var movement = Vector2(-1, 0).normalized()
			CA.state = CA.MOVE
			CA.direction_change(movement)
			if movement_flag: CA.move_to(movement, delta)
			else: CA.stop(delta)
		3:
			# First fight sequence
			Controls.can_move = true
			dialog.visible = false
		4:
			# Robber retaliates
			Controls.can_move = false
			if event_flag: dialog.load_script(script_2)
			dialog.visible = true
		5:
			# Robber Swarm
			Controls.can_move = true
			dialog.visible = false
			if event_flag: Robber_spawner.start_spawn()
		6:
			Controls.can_move = false
			dialog.visible = true
			get_tree().call_group("Enemies", "stop", delta)
			if event_flag: 
				dialog.load_script(script_3)
				Robber_spawner.stop_spawn()
		7:
			# Cut to black
			$Blackout.visible = true
			dialog.visible = false
			$CanvasLayer/Health_Bar.visible = false
		0:
			# Test phase
			Controls.can_move = true
			dialog.visible = false
			#var movement = Vector2(-1, 0).normalized()
			#CA.state = CA.MOVE
			#CA.direction_change(movement)
			#CA.move_to(movement, delta)
	event_flag = false
	print(current_event)

func start_timer(wait_time):
	movement_flag = true
	timer.wait_time = wait_time
	timer.start(wait_time)

func _on_Dialog_dialog_finished():
	event_flag = true

func _on_Robber_enemy_dead():
	if current_event == 3:
		event_flag = true

func _on_Event_Timer_timeout():
	movement_flag = false


func _on_Capt_Awesome_CA_dead():
	if current_event == 5:
		event_flag = true
