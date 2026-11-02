extends Area2D

var target = null

# N.B. Detection code may have to change with introduction of
# more characters

func target_found():
	return target != null

func _on_DetectionZone_body_entered(body):
	target = body

func _on_DetectionZone_body_exited(body):
	target = null
