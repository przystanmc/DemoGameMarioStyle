extends CharacterBody2D

const SPEED = 90.0
const JUMP_VELOCITY = -300.0
const ROLL_SPEED = 120.0 # Przewrót jest szybszy niż bieg
@onready var main_collision = $CollisionShape2D # Upewnij się, że tak nazywa się Twój węzeł kolizji
var original_radius : float
var original_height : float
var original_pos : Vector2
# Odniesienia do węzłów
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer
@export var coin_scene: PackedScene # Przeciągnij tu plik moneta.tscn
@export var hint_icon_scene: PackedScene # Przeciągnij tu plik moneta.tscn
@export var gem_scene: PackedScene
@onready var hand = $Hand
@onready var hand_sprite = $Hand/HandSprite
@onready var sword_collision = $Hand/Sword/SwordArena/SwordCollision

# --- TUTAJ MUSISZ DODAĆ TE LINIE ---

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_rolling = false
var is_hit = false
var active_hint = null # <--- TĘ LINIKĘ MUSISZ DODAĆ
var can_drink = false # Czy jesteśmy przy butelce
var current_bottle_pos = Vector2i.ZERO # Pozycja butelki do usunięcia
var jump_boost = 1.0 # Mnożnik skoku
var max_hp = 30
var current_hp = 30
var coins = 0
var is_frozen: bool = false
var diamond_count = 0 # <--- DODAJ TO
var emerald_count = 0 # <--- DODAJ TO
var apple_count = 0   # <--- DODAJ TO
var boost_timer = 0.0
const HAND_BASE_X = -4 # Dostosuj tak, aby dłoń była przy ciele rycerza
const HAND_BASE_Y = -1
var speed_boost = 1.0        # Mnożnik szybkości biegu
var damage_boost = 1.0       # Mnożnik obrażeń
var is_attacking = false
var light_pulse = 0.0
var night_level: float = 0.0 # Informacja z DayManager (0 do 1)
var target_energy: float = 0.0
var light_pulse_time: float = 0.0
var total_gems = 0 # Nowa zmienna dla samych gemów (opcjonalnie)
@export var max_light_energy: float = 0.8 
@onready var light_node = $TestLight # Upewnij się, że nazwa się zgadza

func _ready():
	# Podłączamy sygnał zakończenia animacji dla obu efektów
	if has_node("Slash"):
		$Slash.animation_finished.connect(func(): $Slash.visible = false)
	if has_node("Slash2"):
		$Slash2.animation_finished.connect(func(): $Slash2.visible = false)
	if main_collision and main_collision.shape is CapsuleShape2D:
		original_radius = main_collision.shape.radius
		original_height = main_collision.shape.height
		original_pos = main_collision.position
	convert_all_tiles_to_gems()
func _physics_process(delta):
	# --- LOGIKA ŚWIATŁA (Wstaw to na początku funkcji) ---
	if light_node:
		# 1. Płynne dążenie do celu (lerp sprawia, że nie ma skoków)
		target_energy = lerp(target_energy, night_level * max_light_energy, 0.05)
		
		# 2. Bardziej naturalne migotanie (złożone z dwóch fal)
		light_pulse_time += delta * 15.0
		var flicker = sin(light_pulse_time) * cos(light_pulse_time * 0.7) * 0.04
		
		# 3. Ustawienie energii (mnożymy flicker przez night_level, żeby nie mrugało w dzień)
		light_node.energy = target_energy + (flicker * night_level)
		
		# 4. Automatyczne zarządzanie węzłem
		if light_node.energy <= 0.01:
			if light_node.enabled: light_node.enabled = false
		else:
			if not light_node.enabled: light_node.enabled = true
			
		# 5. Pulsowanie wielkości (texture_scale)
		light_node.texture_scale = lerp(light_node.texture_scale, 0.8 + (flicker * 0.2), 0.1)
	if not is_on_floor():
		velocity.y += gravity * delta
	if is_rolling:
		var current_time = anim_player.current_animation_position
		if current_time < 0.5: velocity.x = 0
		elif current_time >= 0.5 and current_time < 1.0:
			var roll_dir = -1 if sprite.flip_h else 1
			velocity.x = roll_dir * ROLL_SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, 15.0)
	elif not is_hit:
		handle_input()

	move_and_slide()
	if boost_timer > 0:
		boost_timer -= delta
		var ui = get_tree().get_first_node_in_group("ui")
		if ui: ui.show_boost(boost_timer)
		if boost_timer <= 0:
			reset_boost()
	# --- LOGIKA WYKRYWANIA ---
	var found_sign = check_for_signs()
	var found_item = check_for_items()
	
	if not found_sign and not found_item and active_hint != null:
		# Sprawdzamy, czy tabliczka już nie zaczęła znikać
		if not active_hint.is_closing: 
			if active_hint.has_method("start_disappearing"):
				active_hint.start_disappearing()
				# NIE ustawiamy active_hint = null tutaj, 
				# bo chcemy zablokować tworzenie nowej, póki ta nie zniknie całkiem
			else:
				active_hint.queue_free()
				active_hint = null
	
	# Jeśli ikona została usunięta z drzewa (przez queue_free w jej skrypcie), czyścimy zmienną
	if active_hint != null and not is_instance_valid(active_hint):
		active_hint = null

	if is_on_ceiling():
		check_ceiling_collision()
		
	update_animations()
	update_hand_animation()

func handle_input():
	# 1. Obsługa interakcji i ataku
	if is_frozen: 
		velocity.x = move_toward(velocity.x, 0, SPEED) # Zatrzymujemy go w miejscu
		return
	if Input.is_action_just_pressed("interact") and can_drink:
		drink_potion()

	if Input.is_action_just_pressed("attack") and is_on_floor() and not is_attacking:
		perform_attack()
		return 

	if is_attacking: return 

	# 2. Pobranie kierunku (Definiujemy 'direction' na początku!)
	var direction = Input.get_axis("ui_left", "ui_right")

	# 3. Ruch i Skok
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY * jump_boost

	if direction:
		velocity.x = direction * SPEED * speed_boost
		sprite.flip_h = (direction < 0)
		
		# OBRACANIE DŁONI (Synchronizacja z Rycerzem)
		var side = -1 if sprite.flip_h else 1
		hand.position.x = HAND_BASE_X 
		hand.scale.x = side # To sprawi, że miecz zawsze celuje w stronę marszu
		hand.z_index = 0 if sprite.flip_h else 1
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("roll") and is_on_floor():
		start_roll()
func start_roll():
	is_rolling = true
	shrink_collision() # <--- SKURCZ SIĘ
	anim_player.play("roll")

# W funkcji obsługującej koniec animacji:
func shrink_collision():
	if not main_collision or not main_collision.shape is CapsuleShape2D: return
	
	# Przykład: Zmniejszamy wysokość o połowę
	# Pamiętaj, że w CapsuleShape2D wysokość nie może być mniejsza niż promień * 2
	main_collision.shape.height = original_height * 0.5
	
	# Przesuwamy kolizję w dół, żeby rycerz nie "lewitował" podczas turlania
	main_collision.position.y = original_pos.y + (original_height * 0.25)
func reset_collision():
	if not main_collision or not main_collision.shape is CapsuleShape2D: return
	
	main_collision.shape.radius = original_radius
	main_collision.shape.height = original_height
	main_collision.position.y = original_pos.y
func set_rolling_velocity():
	var roll_dir = -1 if sprite.flip_h else 1
	velocity.x = roll_dir * ROLL_SPEED

# Ta funkcja zostanie wywołana przez AnimationPlayer w 1.3s
func stop_rolling_velocity():
	# Gwałtownie hamujemy, bo postać zaczyna wstawać
	velocity.x = move_toward(velocity.x, 0, SPEED)

# --- NAPRAWIONA FUNKCJA SYGNAŁU ---
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "roll":
		is_rolling = false
		velocity.x = 0 
		reset_collision() # <--- WRÓĆ DO NORMY 
	if anim_name == "attack":
		is_attacking = false	
	if anim_name == "hit":
		is_hit = false
		velocity.x = 0 # Zatrzymujemy odrzut po zakończeniu animacji
func update_animations():
	# 1. Jeśli otrzymaliśmy obrażenia (hit), nie pozwalamy nadpisać animacji
	if is_frozen:
		anim_player.play("idle")
		return
	if is_hit:
		anim_player.play("hit")
		return
		
	# 2. DODAJ TO: Jeśli atakujemy, nie pozwalamy nadpisać animacji
	if is_attacking:
		return

	# 3. Jeśli wykonujemy przewrót (roll), czekamy aż animacja się skończy
	if is_rolling:
		return
	
	if is_on_floor():
		if velocity.x != 0:
			anim_player.play("run")
		else:
			anim_player.play("idle")
			
func update_hand_animation():
	if is_attacking or is_rolling or is_hit: return
	
	var side = -1 if sprite.flip_h else 1
	hand.position.x = HAND_BASE_X 
	hand.scale.x = side 
	
	# Używamy set_z_index, aby upewnić się, że wartość zostanie wysłana do silnika
	if sprite.flip_h:
		hand.z_index = -1 # SPRÓBUJ -1 zamiast 0, żeby mieć pewność, że jest ZA graczem
	else:
		hand.z_index = 1
	# Delikatne falowanie góra-dół
	var bobbing = sin(Time.get_ticks_msec() * 0.008) * 1.5
	hand.position.y = HAND_BASE_Y + bobbing
			
func perform_attack():
	if is_attacking: return
	is_attacking = true
	
	var is_flipped = sprite.flip_h
	var side = -1 if is_flipped else 1
	var current_slash = $Slash2 if is_flipped else $Slash
	
	$Slash.visible = false
	$Slash2.visible = false
	
	var current_base_x = HAND_BASE_X 
	var back_x = (HAND_BASE_X - 4.0) * side 
	var forward_x = (HAND_BASE_X + 12.0) * side
	
	var tween = create_tween()
	
	# --- KROK 1: ZAMACH (Mniejszy kąt, żeby nie zaczynał znad głowy) ---
	# Zmieniamy -45 na -20 stopni
	tween.tween_property(hand, "rotation_degrees", -20.0 * side, 0.05)
	tween.parallel().tween_property(hand, "position:x", back_x, 0.05)
	
	# --- KROK 2: CIĘCIE (Mniejszy kąt końcowy, żeby nie wbijał w ziemię) ---
	tween.tween_callback(func():
		if current_slash:
			current_slash.visible = true
			current_slash.frame = 0
			current_slash.speed_scale = 12.0
			current_slash.play("Slash")
		if sword_collision:
			sword_collision.disabled = false  
	)
	
	# Zmieniamy 110 stopni na 45-60 stopni (bardziej poziomo)
	# Dodajemy też lekkie podniesienie ręki w górę (-2), żeby nie szorowała po nogach
	tween.tween_property(hand, "rotation_degrees", 100.0 * side, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hand, "position:x", forward_x, 0.08)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y - 2.0, 0.08) # <--- TO PODNOSI MIECZ
	
	# --- KROK 3: WYŁĄCZENIE HITBOXA ---
	tween.tween_callback(func():
		if sword_collision:
			sword_collision.disabled = true
	)
	
	# --- KROK 4: POWRÓT ---
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		$Slash.visible = false
		$Slash2.visible = false
	)
	
	tween.tween_property(hand, "rotation_degrees", 0, 0.1)
	tween.parallel().tween_property(hand, "position:x", current_base_x, 0.1)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y, 0.1) # <--- WRACA DO BAZY
	
	await tween.finished
	is_attacking = false
	
func take_damage(attacker_pos = Vector2.ZERO): # Dodajemy argument
	if not is_hit and not is_rolling:
		current_hp -= 5
		var ui = get_tree().get_first_node_in_group("ui")
		if ui: ui.update_hp(current_hp, max_hp)
		
		is_hit = true
		
		# OBLICZANIE ODRZUTU NA PODSTAWIE POZYCJI ATAKUJĄCEGO
		# Jeśli demon jest po prawej, odskocz w lewo i na odwrót
		var knockback_dir = 1 if attacker_pos.x < global_position.x else -1
		
		velocity.x = knockback_dir * 150 # Siła odrzutu
		velocity.y = -100 # Lekki podskok przy otrzymaniu obrażeń
		
		sprite.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color(1, 1, 1)
		anim_player.play("hit")
	
func check_ceiling_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if collision.get_normal().y > 0.5:
			var collider = collision.get_collider()
			
			if collider is TileMapLayer:
				var hit_pos = collision.get_position() - collision.get_normal() * 4
				var tile_pos = collider.local_to_map(collider.to_local(hit_pos))
				var atlas_coords = collider.get_cell_atlas_coords(tile_pos)
				
				# Pełna lista kafelków, o które prosiłeś:
				var coin_tiles = [
					Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 3),
					Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
					Vector2i(7, 2), Vector2i(8, 2)
				]
				
				if atlas_coords in coin_tiles:
					hit_coin_tile(collider, tile_pos)

func hit_coin_tile(layer: TileMapLayer, tile_pos: Vector2i):
	# 1. Usuwamy kafelek
	layer.set_cell(tile_pos, -1)
	
	# 2. Losujemy szansę (0.0 do 1.0)
	var chance = randf()
	var spawn_pos = layer.to_global(layer.map_to_local(tile_pos))
	
	# 3. Sprawdzamy co wypadło
	if chance < 0.10: # 10% na Diament
		spawn_loot(gem_scene, spawn_pos, 0)
	elif chance < 0.20: # 10% na Szmaragd
		spawn_loot(gem_scene, spawn_pos, 1)
	elif chance < 0.30: # 10% na Jabłko
		spawn_loot(gem_scene, spawn_pos, 2)
	elif chance < 0.80: # 50% na Monetę (0.30 + 0.50 = 0.80)
		spawn_loot(coin_scene, spawn_pos)
	else: # Pozostałe 20%
		print("Pusto! Nic nie wypadło.")

# Funkcja pomocnicza, żeby nie powtarzać kodu instancjonowania
func spawn_loot(scene: PackedScene, pos: Vector2, type: int = -1):
	if not scene: return
	
	var item = scene.instantiate()
	get_parent().add_child(item)
	item.global_position = pos
	
	# Jeśli to gem (ma zmienną gem_type), ustawiamy mu odpowiedni typ
	if type != -1 and "gem_type" in item:
		item.gem_type = type
		if item.has_method("setup_gem"):
			item.setup_gem()
	
	print("Wypadł przedmiot: ", item.name)
	
func check_for_signs() -> bool:
	var tile_layer = get_tree().get_first_node_in_group("interactable_map")
	if not tile_layer: return false

	var check_pos_global = global_position + Vector2(0, -6)
	var player_tile = tile_layer.local_to_map(tile_layer.to_local(check_pos_global))
	var found_sign = false
	
	for x in range(-1, 2):
		for y in range(-1, 4):
			var current_check = player_tile + Vector2i(x, y)
			var atlas_coords = tile_layer.get_cell_atlas_coords(current_check)
			
			# TABLICZKA 1: WITAJ (8, 4)
			# Wewnątrz pętli w check_for_signs()
			# Wewnątrz pętli w check_for_signs()
			# Pobieramy ID alternatywne (0 to domyślny, 1, 2 itd. to Twoje warianty)
			var alt_id = tile_layer.get_cell_alternative_tile(current_check)

			# TABLICZKA: WITAJ GRACZU (8, 3, ID 0)
			if atlas_coords == Vector2i(8, 3) and alt_id == 0:
				found_sign = true
				show_hint_at(tile_layer, current_check, "sign2")
				break

			# TABLICZKA: SHIFT / TURLANIE (8, 3, ID 1) <--- TWOJA ZMIANA
			elif atlas_coords == Vector2i(8, 3) and alt_id == 1:
				found_sign = true
				show_hint_at(tile_layer, current_check, "sign_roll")
				break

			# TABLICZKA: SAMA IKONA (8, 4, ID 0)
			elif atlas_coords == Vector2i(8, 4):
				found_sign = true
				show_hint_at(tile_layer, current_check, "sign_jump")
				break
				
		if found_sign: break
	
	return found_sign
func show_hint_at(layer, tile_pos, type = "sign"):
	if active_hint != null: return
	
	if hint_icon_scene:
		var instance = hint_icon_scene.instantiate()
		
		# 1. NAJPIERW ustawiamy tryb
		instance.mode = type 
		
		# 2. POTEM dodajemy do drzewa (to odpali _ready w ikonie)
		get_tree().current_scene.add_child(instance)
		
		# 3. Ustawiamy pozycję i Z-index
		instance.z_index = 5 
		var sign_pos = layer.to_global(layer.map_to_local(tile_pos))
		instance.global_position = sign_pos + Vector2(0, -30)
		
		active_hint = instance
		print("IKONA STWORZONA: ", type, " POZYCJA: ", instance.global_position)

func destroy_crate(layer: TileMapLayer, pos: Vector2i):
	# Usuwamy kafelek skrzyni
	layer.set_cell(pos, -1)
	print("Skrzynia zniszczona na pozycji: ", pos)
	
	# Opcjonalnie: wypadanie monety ze skrzyni (np. 50% szans)
	if randf() > 0.5:
		hit_coin_tile(layer, pos)

		
func check_for_items() -> bool:
	var tile_layer = get_node_or_null("../background/Background/tille")
	if not tile_layer: return false

	# Sprawdzamy nieco przed graczem i na wysokości klatki piersiowej
	var check_pos = global_position + Vector2(4, -8) 
	var player_tile = tile_layer.local_to_map(tile_layer.to_local(check_pos))
	var found_item = false
	
	# --- KONFIGURACJA KORDÓW ATLASU ---
	var bottle_coords = [
		Vector2i(0, 7), Vector2i(1, 7), 
		Vector2i(0, 8), Vector2i(1, 8)
	]

	
	# Przeszukujemy mały obszar wokół punktu check_pos
	for x in range(-1, 2): 
		for y in range(-1, 3):
			var current_check = player_tile + Vector2i(x, y)
			var atlas_coords = tile_layer.get_cell_atlas_coords(current_check)
			
			# 1. LOGIKA BUTELEK (wymagają interakcji - przycisk E/F)
			if atlas_coords in bottle_coords:
				found_item = true
				can_drink = true
				current_bottle_pos = current_check
				show_hint_at(tile_layer, current_check, "bottle")
				break

						
				break
				
		if found_item: break
	
	if not found_item: can_drink = false
	return found_item
func convert_all_tiles_to_gems():
	var tile_layer = get_node_or_null("../background/Background/tille")
	if not tile_layer: return

	# Pobieramy granice narysowanych kafelków na mapie
	var used_cells = tile_layer.get_used_cells()
	
	# Kordy gemów do wykrycia
	var gem_diamond = Vector2i(10, 11)
	var gem_emerald = Vector2i(11, 11)
	var gem_apple = Vector2i(12, 11)

	for cell_pos in used_cells:
		var atlas_coords = tile_layer.get_cell_atlas_coords(cell_pos)
		
		if atlas_coords == gem_diamond or atlas_coords == gem_emerald or atlas_coords == gem_apple:
			# Usuwamy kafelek
			tile_layer.set_cell(cell_pos, -1)
			
			# Tworzymy scenę kryształu
			if gem_scene:
				var gem = gem_scene.instantiate()
				get_parent().add_child.call_deferred(gem) # Używamy call_deferred dla bezpieczeństwa w _ready
				
				# Pozycjonowanie
				var global_pos = tile_layer.to_global(tile_layer.map_to_local(cell_pos))
				gem.global_position = global_pos
				
				# Ustawianie typu
				if "gem_type" in gem:
					if atlas_coords == gem_diamond: gem.gem_type = 0
					elif atlas_coords == gem_emerald: gem.gem_type = 1
					elif atlas_coords == gem_apple: gem.gem_type = 2
					
					# Setup (używamy call_deferred, by upewnić się, że węzły @onready w gemie już działają)
					if gem.has_method("setup_gem"):
						gem.call_deferred("setup_gem")
func drink_potion():
	var tile_layer = get_node_or_null("../background/Background/tille")
	if not tile_layer: return

	var atlas_coords = tile_layer.get_cell_atlas_coords(current_bottle_pos)
	tile_layer.set_cell(current_bottle_pos, -1) 
	
	reset_boost()
	boost_timer = 10.0 
	
	# 1. Logika efektów (najpierw obliczamy zmiany w HP)
	match atlas_coords:
		Vector2i(0, 7): # ZIELONA
			jump_boost = 1.6
			sprite.modulate = Color(0.5, 1.5, 0.5)
			
		Vector2i(0, 8): # NIEBIESKA
			current_hp = min(current_hp + 10, max_hp)
			sprite.modulate = Color(0.5, 0.8, 1.5)
			boost_timer = 1.0 # Krótki błysk dla leczenia
			
		Vector2i(1, 7): # ŻÓŁTA
			damage_boost = 2.0
			sprite.modulate = Color(1.5, 1.5, 0.2)
			
		Vector2i(1, 8): # FIOLETOWA
			speed_boost = 1.7
			sprite.modulate = Color(1.2, 0.5, 1.5)

	# 2. Aktualizacja UI (robimy to NA KOŃCU, żeby UI widziało już nowe HP)
	var ui = get_tree().get_first_node_in_group("ui")
	if ui: 
		ui.show_boost(boost_timer, atlas_coords)
		ui.update_hp(current_hp, max_hp) # Teraz pasek życia od razu "skoczy" w górę

	if active_hint:
		active_hint.queue_free()
		active_hint = null
func reset_boost():
	jump_boost = 1.0
	speed_boost = 1.0
	damage_boost = 1.0
	sprite.modulate = Color(1, 1, 1) # Powrót do normalnego koloru




# W Knight.gd

# W Knight.gd
func add_gem(type: int, sprite_frames: SpriteFrames = null, anim_name: String = ""):
	var ui = get_tree().get_first_node_in_group("ui")
	
	# --- 1. SPOWOLNIONY I PŁYNNY EFEKT WIZUALNY ---
	if sprite_frames and sprite_frames.has_animation("take"):
		var take_effect = AnimatedSprite2D.new()
		take_effect.sprite_frames = sprite_frames
		take_effect.animation = "take"
		
		# Ustawienia bazowe
		take_effect.position = Vector2(0, -10)
		take_effect.z_index = -1 
		
		# --- REGULACJA PRĘDKOŚCI KLATEK ---
		# 1.0 to norma, 0.5 to połowa prędkości (wolniej), 0.3 to bardzo powoli
		take_effect.speed_scale = 0.6 
		
		add_child(take_effect)
		
		# --- TWEEN DLA DYNAMICZNEGO EFEKTU ---
		var tween = create_tween()
		
		# Parametry startowe
		take_effect.scale = Vector2(0.3, 0.3) # Zaczyna jako malutki punkt
		take_effect.modulate.a = 0.0
		
		# 1. Płynne pojawianie się i powiększanie
		# Zmieniamy czas z 0.15 na 0.4 sekundy (wolniej)
		tween.tween_property(take_effect, "scale", Vector2(1.5, 1.5), 0.4).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(take_effect, "modulate:a", 1.0, 0.3)
		

		
		# 3. Płynne znikanie na koniec
		tween.tween_property(take_effect, "modulate:a", 0.0, 0.3)
		
		take_effect.play()
		
		# Usuwamy efekt po zakończeniu Tweena
		tween.finished.connect(func():
			take_effect.queue_free()
		)

	# --- 2. RESZTA LOGIKI (DIAMENT / SZMARAGD / JABŁKO) ---
	# Tutaj zostaje Twój stary kod match type...
	# --- 2. LOGIKA ZBIERANIA I UI (Twój istniejący kod) ---
	match type:
		0: # DIAMENT
			diamond_count += 1
			if ui: 
				# Przesyłamy: typ, ilość, klatki animacji i nazwę animacji docelowej
				ui.update_gem_ui(type, diamond_count, sprite_frames, anim_name)
				
		1: # SZMARAGD
			emerald_count += 1
			if ui: 
				ui.update_gem_ui(type, emerald_count, sprite_frames, anim_name)
			
		2: # JABŁKO (Zwiększenie MAX HP)
			var heart_value = 10 
			max_hp += heart_value
			current_hp = max_hp
			
			if ui:
				ui.update_hp(current_hp, max_hp)
			
			var tween = create_tween()
			sprite.modulate = Color(2, 2, 0) # Złoty błysk
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
			
			print("Max HP zwiększone do: ", max_hp)
func add_coin():
	coins += 1
	# Szukamy UI w grupie i aktualizujemy tekst
	var ui = get_tree().get_first_node_in_group("ui")
	if ui: 
		ui.update_coins(coins)
	
	


func _on_death_zone_body_entered(body: Node2D) -> void:
# Ponieważ ten skrypt jest NA RYCERZU, 'body' to obiekt, który wszedł w strefę.
	# Musimy sprawdzić, czy to MY (Rycerz) weszliśmy w strefę śmierci.
	if body == self: 
		print("Rycerz spadł! Restart...")
		restart_level()

func restart_level():
	print("Rycerz spadł! Restart...")
	# Używamy call_deferred, aby poczekać do końca klatki fizyki
	get_tree().call_deferred("reload_current_scene")

	
func end_attack():
	is_attacking = false


func _on_sword_arena_body_entered(body: Node2D) -> void:
	if body != self and body.has_method("take_damage"):
		# Przekazujemy damage_boost do przeciwnika
		# Zakładając, że bazowe obrażenia to np. 10
		var final_damage = 10 * damage_boost
		body.take_damage(final_damage) 
		print("Gracz uderzył za: ", final_damage)
# Funkcja odbierająca sygnał z DayManager
	
func update_flicker_energy(new_energy: float):
	# Szukamy światła u rycerza (zakładam, że nazywa się PointLight2D)
	var light = get_node_or_null("TestLight")
	if light:
		# Płynnie ustawiamy energię na podstawie night_intensity
		light.energy = new_energy

# Funkcja fizycznie włączająca/wyłączająca węzeł
func sync_night_intensity(intensity: float):
	night_level = intensity
