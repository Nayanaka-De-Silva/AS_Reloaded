extends CanvasLayer

func _on_StartButton_pressed():
	#get_tree().change_scene("res://World_2.tscn")
	get_tree().change_scene_to_file("res://Levels/level_1.tscn")

func _on_QuitButton_pressed():
	get_tree().quit()
