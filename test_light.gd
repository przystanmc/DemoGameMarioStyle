extends PointLight2D

@export var flicker_speed: float = 8.0  
@export var flicker_strength: float = 0.1 

var target_energy: float = 0.0 
var time_passed: float = 0.0

# ZMIENIONA NAZWA FUNKCJI
func update_light_energy(new_energy: float):
	target_energy = new_energy

func _process(delta):
	# Sterujemy widocznością na podstawie energii z DayManagera
	enabled = target_energy > 0
	
	if enabled:
		time_passed += delta * flicker_speed
		var flicker = sin(time_passed) * cos(time_passed * 0.7) * flicker_strength
		energy = target_energy + flicker
		texture_scale = 1.0 + (flicker * 0.5)
