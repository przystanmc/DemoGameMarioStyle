extends HBoxContainer

# PAMIĘTAJ: Przeciągnij tutaj swoją scenę Heart.tscn w Inspektorze!
@export var heart_scene: PackedScene 

var last_hp: int = -1
var is_spawning: bool = true

func _ready():
	# 1. Czyścimy śmieci z edytora
	for child in get_children():
		child.queue_free()
	
	# 2. Czekamy chwilę na załadowanie gracza
	await get_tree().process_frame
	
	is_spawning = true
	await spawn_initial_hearts()
	is_spawning = false

func spawn_initial_hearts():
	var player = get_tree().get_first_node_in_group("player")
	# Jeśli nie znajdzie gracza, przyjmujemy Twoje wartości domyślne: 30 HP
	var current_hp = player.current_hp if player else 30
	var max_hp = player.max_hp if player else 30
	
	# Obliczamy liczbę serc: 30 / 10 = 3 serca
	var total_hearts = int(max_hp / 10.0)

	for i in range(total_hearts):
		if heart_scene:
			var heart = heart_scene.instantiate()
			add_child(heart)
			
			# Czekamy na @onready wewnątrz serca
			await get_tree().process_frame
			
			# Każde serce odpowiada kolejnym dziesiątkom (10, 20, 30)
			var heart_value = (i + 1) * 10
			
			if current_hp >= heart_value:
				heart.animate_spawn() # Pełne
			elif current_hp >= heart_value - 5:
				heart.update_heart("half") # Połowa
			else:
				heart.update_heart("empty") # Puste
				
			await get_tree().create_timer(0.1).timeout # Efekt fali przy startu
	
	last_hp = current_hp

# Ta funkcja jest wywoływana przez GameUI.gd
func update_health(hp: int, max_hp: int): # Teraz używamy _max_hp jako max_hp
	if is_spawning: return 
	
	# 1. SPRAWDZANIE CZY POTRZEBNE SĄ NOWE SERCA (JABŁKO)
	var target_heart_count = int(max_hp / 10.0) # Dodanie .0 wymusza dzielenie zmiennoprzecinkowe
	var current_heart_count = get_child_count()
	
	if target_heart_count > current_heart_count:
		# Dodajemy brakujące serca
		for i in range(target_heart_count - current_heart_count):
			if heart_scene:
				var new_heart = heart_scene.instantiate()
				add_child(new_heart)
				# Wywołujemy animację pojawienia się dla nowego serca
				new_heart.animate_spawn() 
	
	# 2. AKTUALIZACJA STANÓW (Twój istniejący kod)
	for i in range(get_child_count()):
		var heart = get_child(i)
		var heart_value = (i + 1) * 10
		var state = ""
		
		if hp >= heart_value: 
			state = "full"
		elif hp >= heart_value - 5: 
			state = "half"
		else: 
			state = "empty"
		
		# --- LOGIKA ANIMACJI (Bez zmian) ---
		if last_hp > hp:
			var lost_full = last_hp >= heart_value and hp < heart_value
			if lost_full:
				heart.animate_deplete(state == "empty")
			else:
				heart.update_heart(state)
		
		elif last_hp < hp:
			# Sprawdzamy czy serce jest nowe (mogło nie mieć last_hp)
			var gained_full = (last_hp < heart_value or last_hp == -1) and hp >= heart_value
			var gained_half = (last_hp < heart_value - 5 or last_hp == -1) and hp >= heart_value - 5
			
			if gained_full:
				heart.animate_restore_full()
			elif gained_half:
				heart.animate_restore_half()
			else:
				heart.update_heart(state)
		else:
			heart.update_heart(state)

	last_hp = hp
