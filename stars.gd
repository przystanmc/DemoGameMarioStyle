extends Node2D

@onready var tilemap_layer = get_tree().root.find_child("tille", true, false)
@onready var prototype_star = $Stars 
@onready var coin_layer = get_tree().root.find_child("coinLayer", true, false)
@onready var slime_layer = get_tree().root.find_child("SlimeLayer", true, false)
@onready var background_layer = get_tree().root.find_child("Background", true, false)
func _ready():
	add_to_group("stars_manager")
	if prototype_star:
		prototype_star.hide()
	
	await get_tree().process_frame
	
	if tilemap_layer:
		generate_stars()

func generate_stars():
	var used_rect = tilemap_layer.get_used_rect()
	
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var coords = Vector2i(x, y)
			
			# --- NOWA LOGIKA: SPRAWDZANIE CZY JESTEŚMY WEWNĄTRZ ---
			var is_inside = false
			if background_layer:
				var bg_data = background_layer.get_cell_tile_data(coords)
				if bg_data and bg_data.get_custom_data("inside") == true:
					is_inside = true
			
			# Jeśli jesteśmy "inside", pomijamy ten kafelek i idziemy do następnego
			if is_inside:
				continue
			# ----------------------------------------------------

			var data_tile = tilemap_layer.get_cell_tile_data(coords)
			
			var has_coin = false
			if coin_layer:
				has_coin = coin_layer.get_cell_source_id(coords) != -1
							
			var has_slime = false
			if slime_layer:
				has_slime = slime_layer.get_cell_source_id(coords) != -1

			# Gwiazda pojawi się TYLKO jeśli wszędzie jest pusto i NIE jesteśmy wewnątrz
			if data_tile == null and not has_coin and not has_slime: 
				if randf() < 0.03:
					var new_star = prototype_star.duplicate()
					add_child(new_star)
					new_star.show()
					
					new_star.global_position = tilemap_layer.map_to_local(coords)
					
					new_star.hframes = 4
					new_star.frame = 3 # Zaczynamy od ciemnej klatki
					
					new_star.scale = prototype_star.scale * randf_range(0.6, 1.0)
					
					animate_star(new_star)
func animate_star(star: Sprite2D):
	# Szukamy Twojego węzła starlight
	var light = star.get_node_or_null("starlight")
	
	var start_delay = randf_range(0.0, 3.0)
	var duration = randf_range(1.5, 3.0) 
	
	var tween = create_tween().set_loops()
	tween.tween_interval(start_delay)
	
	# --- ETAP 1: ROZPALANIE (3 -> 2 -> 1 -> 0) ---
	
	# Start: Klatka 3 - Światło znika całkowicie (skala 0)
	tween.tween_callback(func(): 
		if is_instance_valid(star): star.frame = 3
		if light: light.texture_scale = 0.0
	)
	tween.tween_interval(duration * 0.2)
	
	# Klatka 2 i 1 - Sprite rośnie
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 2)
	tween.tween_interval(0.1)
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 1)
	tween.tween_interval(0.1)
	
	# Klatka 0 - FULL BLASK (Światło rośnie do 0.5)
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 0)
	if light:
		# Płynnie powiększamy skalę tekstury do 0.5
		tween.parallel().tween_property(light, "texture_scale", 0.8, 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(light, "energy", 1.2, 0.3)
	
	tween.tween_interval(duration * 0.4) 
	
	# --- ETAP 2: GASZENIE (0 -> 1 -> 2 -> 3) ---
	
	# Światło kurczy się z powrotem do 0
	if light:
		tween.tween_property(light, "texture_scale", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(light, "energy", 0.0, 0.3)
	
	# Dopasowanie klatek sprite'a do znikającego światła
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 1)
	tween.tween_interval(0.15)
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 2)
	tween.tween_interval(0.15)
	tween.tween_callback(func(): if is_instance_valid(star): star.frame = 3)
func update_stars_opacity(opacity: float):
	# Zamiast modulate.a (które wpływa na wszystko), możemy sterować widocznością całego węzła
	# Gwiazdy pojawią się tylko w głębokiej nocy
	self.visible = opacity > 0.1
	# Dodatkowo możemy przyciemnić je globalnie, jeśli noc jest jeszcze młoda
	self.modulate.a = clamp(opacity * 1.5, 0.0, 1.0)
