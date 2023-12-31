extends Control

var hearts = 4: set = set_hearts
var max_hearts = 4: set = set_max_hearts

@onready var heartUIFull = $Heart_full
@onready var heartUIEmpty = $Heart_empty

func set_hearts(value):
	hearts = clamp(value, 0, max_hearts)
	if heartUIFull != null:
		heartUIFull.size.x = hearts * 15

func set_max_hearts(value):
	max_hearts = max(value, 1)
	self.hearts = min(hearts, max_hearts)
	if heartUIEmpty != null:
		heartUIEmpty.size.x = max_hearts * 15

func _ready():
	max_hearts = CA_Stats.max_health
	self.hearts = CA_Stats.health
	CA_Stats.connect("health_changed", Callable(self, "set_hearts"))
	CA_Stats.connect("max_health_changed", Callable(self, "set_max_hearts"))
