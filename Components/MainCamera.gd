extends Camera2D

@onready var Camera_anim = $AnimationPlayer

var Shift = [
	"ShiftRight",
	"ShiftLeft"
]

func shift_camera():
	Shift.shuffle()
	Camera_anim.play(Shift[0])


func _on_Capt_Awesome_CA_hurt():
	shift_camera()


func _on_Capt_Awesome_CA_punch():
	shift_camera()
