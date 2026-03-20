extends Control

@export var ANGLE_START: float = 0.0
@export var ANGLE_END: float = 180.0
@export var FRAME_HEIGHT: float = 16.0 

@onready var arrow = $Line2D 
@onready var icon_sprite = $WeatherIcon 

func update_ui(time_percent: float):
	# 1. LOGIKA CZASU
	var hour = time_percent * 24.0
	var offset_time = fmod(time_percent + (1.0 - 4.0/24.0), 1.0)
	arrow.rotation_degrees = lerp(ANGLE_START, ANGLE_END, offset_time)
	
	# 2. OBLICZANIE POZYCJI (Płynny float)
	var current_pos_frames: float = 0.0
	
	if hour >= 4.0 and hour < 6.0:
		current_pos_frames = remap(hour, 4.0, 6.0, 0.0, 1.0)
	elif hour >= 6.0 and hour < 14.0:
		current_pos_frames = remap(hour, 6.0, 14.0, 1.0, 2.0)
	elif hour >= 14.0 and hour < 16.0:
		current_pos_frames = remap(hour, 14.0, 16.0, 2.0, 3.0)
	elif hour >= 16.0 and hour < 19.0:
		current_pos_frames = remap(hour, 16.0, 19.0, 3.0, 4.0)
	elif hour >= 19.0 and hour < 21.0:
		current_pos_frames = remap(hour, 19.0, 21.0, 4.0, 5.0)
	else:
		# NOC: Stoi do 3:00, potem rusza
		if hour >= 21.0 or hour < 3.0:
			current_pos_frames = 5.0
		else:
			current_pos_frames = remap(hour, 3.0, 4.0, 5.0, 6.0)
	
	# 3. ROZWIĄZANIE PROBLEMU SKOKÓW
	# Usuwamy floor()! Pozwalamy na wartości typu 16.1, 16.2 itd.
	# Dzięki Texture Repeat: Enabled, wartość 96.5 automatycznie pokaże 0.5 obrazka.
	var final_y = current_pos_frames * FRAME_HEIGHT
	
	# Ustawiamy bezpośrednio - Texture Repeat zajmie się zapętleniem (loop)
	icon_sprite.region_rect.position.y = final_y
