extends Sprite2D

@export var fps: float = 10.0
var current_frame: float = 0.0

func _process(delta: float) -> void:
	# Zliczanie czasu i przeliczanie na klatki
	current_frame += delta * fps
	
	# Zapętlenie (modulo hframes zapewnia, że nie wyjdziemy poza zakres)
	if current_frame >= hframes:
		current_frame = 0.0
	
	# Przypisanie klatki (rzutowanie na int)
	frame = int(current_frame)
