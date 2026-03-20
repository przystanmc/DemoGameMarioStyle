extends Node2D

@export var time_speed: float = 5.0 
@export var time_gradient: Gradient 
@export var canvas_modulator: CanvasModulate 
@export var stars_node: Node2D  

var current_time: float = 0.0
const MAX_TIME: float = 1500.0 

func _ready():
	# Ustawiamy czas na 10:00 rano przy starcie
	# 1500 / 24 godziny = 62.5 na godzinę. 10 * 62.5 = 625
	current_time = 625.0
	
	# Wywołujemy aktualizację od razu, żeby świat nie "mignął" 
	# domyślnym kolorem przed pierwszą klatką _process
	update_day_cycle(0)

func _process(delta):
	update_day_cycle(delta)
	
	var current_time_percent = current_time / MAX_TIME
	
	# Próbujemy znaleźć UI w całej scenie, jeśli standardowa ścieżka zawiedzie
	var ui = get_node_or_null("Control/WeatherUI")
	if ui == null:
		# Jeśli nie ma pod CanvasLayer, szukamy w całej scenie (wolniejsze, ale zadziała do testu)
		ui = get_tree().root.find_child("WeatherUI", true, false)
		
	if ui and ui.has_method("update_ui"):
		ui.update_ui(current_time_percent)
	else:
		# To POWINNO się pojawić w konsoli, jeśli jest problem z połączeniem
		print("BŁĄD: Skrypt cyklu nie widzi WeatherUI!")
func update_day_cycle(delta):
	# 1. Licznik czasu
	current_time += delta * time_speed
	if current_time >= MAX_TIME:
		current_time = 0.0
	
	# Aktualizacja zegara w UI
	get_tree().call_group("ui", "update_clock", current_time, MAX_TIME)
	
	var time_ratio = current_time / MAX_TIME
	
	# 2. Kolorowanie świata (CanvasModulate)
	if time_gradient and canvas_modulator:
		canvas_modulator.color = time_gradient.sample(time_ratio)
	
	# 3. Logika intensywności nocy
	var night_intensity = 0.0
	
	if current_time < 300 or current_time > 1200:
		if current_time < 150 or current_time > 1350:
			night_intensity = 1.0 
		elif current_time >= 150 and current_time <= 300:
			var raw_fade = 1.0 - smoothstep(150, 300, current_time)
			night_intensity = pow(raw_fade, 2.0)
		elif current_time >= 1200 and current_time <= 1350:
			var raw_fade = smoothstep(1200, 1350, current_time)
			night_intensity = pow(raw_fade, 2.0)
	
	# 4. Powiadamianie grup
	get_tree().call_group("stars_manager", "update_stars_opacity", night_intensity)
	get_tree().call_group("knight_lights", "sync_night_intensity", night_intensity)
