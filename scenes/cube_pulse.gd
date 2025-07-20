extends CSGBox3D

@export var pulse_speed: float = 1.0
@export var pulse_magnitude: float = 0.3

var base_scale: Vector3
var time_passed: float = 0.0

func _ready():
	base_scale = scale

func _process(delta):
	time_passed += delta * pulse_speed
	var pulse_factor = 1.0 + sin(time_passed) * pulse_magnitude
	scale = base_scale * pulse_factor