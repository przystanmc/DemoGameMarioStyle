extends CharacterBody2D

enum State { IDLE, PATROL, CHASE }
var current_state = State.PATROL

@onready var sprite = $AnimatedSprite2D
@onready var hand = $Hand
@onready var sword_collision = $Hand/Sword/SwordArena/SwordCollision

@export var target: Node2D
@export var detect_range := 70.0
@export var attack_range := 30.0
var night_level: float = 0.0      # Poziom nocy (0.0 - 1.0) przekazywany z DayManager
var target_energy: float = 0.0    # Cel dla lerp
var light_pulse_time: float = 0.0 # Czas dla fali pulsowania
@export var max_light_energy: float = 0.8 
@export var edge_check_dist := 14.0 # Jak daleko przed sobą patrzy (piksele)
@onready var light_node = $TestLight # Upewnij się, że nazwa w drzewie to TestLight

# --- PARAMETRY RUCHU ---
var speed_walk := 40.0
var speed_run := 80.0
var health := 5
var is_attacking := false
var is_dead := false
var can_attack := true

# --- ZMIENNE PATROLU ---
var patrol_dir := 1
var patrol_timer := 0.0
var patrol_idle_timer := 0.0       # [NOWE] Czas trwania chwilowego postoju
var is_patrol_idle := false        # [NOWE] Czy demon stoi w miejscu podczas patrolu

# [NOWE] Limit odległości od punktu startowego
var start_position := Vector2.ZERO
@export var patrol_radius := 96.0  # Maksymalna odległość od startu (w pikselach)

const BLOCK_SIZE = 16.0
const PATROL_DISTANCE = 6 * 16.0
var is_hit := false
const HAND_BASE_X = -6.0
const HAND_BASE_Y = 6.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func get_look_direction() -> int:
	return -1 if sprite.flip_h else 1

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

	# [NOWE] Zapamiętujemy pozycję startową
	start_position = global_position

	# Losowy timer startowy — żeby nie zmieniał kierunku od razu w klatce 0
	patrol_timer = randf_range(2.0, 4.0)

	if has_node("Slash"):
		$Slash.visible = false
		$Slash.animation_finished.connect(func(): $Slash.visible = false)

func _physics_process(delta):
	if is_dead: 
		if light_node: light_node.enabled = false
		return

	# --- LOGIKA ŚWIATŁA (Wstaw to tutaj) ---
	if light_node:
		# 1. Płynne dążenie do jasności nocy (lerp zapobiega nagłym skokom)
		target_energy = lerp(target_energy, night_level * max_light_energy, 0.05)
		
		# 2. Magiczne migotanie (upiorny efekt Nekromanty)
		light_pulse_time += delta * 12.0 
		var flicker = sin(light_pulse_time) * cos(light_pulse_time * 0.7) * 0.06
		
		# 3. Ustawienie finalnej energii
		light_node.energy = target_energy + (flicker * night_level)
		
		# 4. Automatyczne wyłączanie w dzień dla wydajności
		light_node.enabled = light_node.energy > 0.01
			
		# 5. Delikatne pulsowanie wielkości (texture_scale)
		light_node.texture_scale = lerp(light_node.texture_scale, 0.9 + (flicker * 1.5), 0.1)
	# 1. GRAWITACJA
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. LOGIKA AI
	if not is_hit and not is_attacking:
		var dist = 9999.0
		if target:
			dist = global_position.distance_to(target.global_position)

		# Zmiana stanów
		if dist < detect_range:
			current_state = State.CHASE
			is_patrol_idle = false  # Przerywamy postój jeśli gracz w zasięgu
		else:
			if current_state == State.CHASE:
				current_state = State.PATROL
				patrol_timer = 2.0

			_tick_patrol_timers(delta)

		handle_ai_movement(dist, delta)

	# 3. OBSŁUGA ODRZUTU
	if is_hit:
		velocity.x = move_toward(velocity.x, 0, speed_run * delta * 10)
		if sprite.animation != "hit":
			sprite.play("hit")

	move_and_slide()
	update_hand_animation()

# [NOWE] Osobna funkcja do obsługi timerów patrolu — porządek w _physics_process
func _tick_patrol_timers(delta):
	if is_patrol_idle:
		# Odliczamy czas postoju
		patrol_idle_timer -= delta
		if patrol_idle_timer <= 0:
			is_patrol_idle = false
			patrol_timer = randf_range(2.0, 4.0)
	else:
		patrol_timer -= delta
		if patrol_timer <= 0:
			# Losowo: 30% szans na chwilowy postój, 70% na zmianę kierunku
			if randf() < 0.3:
				is_patrol_idle = true
				patrol_idle_timer = randf_range(0.8, 2.5)
			else:
				patrol_dir *= -1
				patrol_timer = randf_range(2.0, 4.0)

func perform_attack():
	is_attacking = true
	var side = get_look_direction()
	var current_base_x = HAND_BASE_X
	var back_x = current_base_x - (2.0 * side)
	var reach_x = current_base_x + (4.0 * side)
	var slash = $Slash

	if slash:
		slash.visible = false
		slash.scale.x = abs(slash.scale.x) * side
		slash.position.x = 10 * side

	var tween = create_tween()

	# 1. Przygotowanie (zamach)
	tween.tween_property(hand, "rotation_degrees", -45.0 * side, 0.15)
	tween.parallel().tween_property(hand, "position:x", back_x, 0.15)

	# 2. START ANIMACJI WIZUALNEJ
	tween.tween_callback(func():
		if slash:
			slash.visible = true
			slash.frame = 0
			slash.play("Slash")
	)

	# --- TUTAJ DODAJEMY OPÓŹNIENIE (np. 0.05 sekundy) ---
	# To sprawi, że kolizja włączy się chwilę po pojawieniu się efektu Slash
	tween.tween_interval(0.05) 

	# 3. WŁĄCZENIE KOLIZJI
	tween.tween_callback(func():
		if sword_collision:
			sword_collision.disabled = false
	)

	# 4. Ruch ręki do przodu (uderzenie)
	tween.tween_property(hand, "rotation_degrees", 60.0 * side, 0.12).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(hand, "position:x", reach_x, 0.12)

	# 5. WYŁĄCZENIE KOLIZJI
	tween.tween_callback(func():
		if sword_collision:
			sword_collision.disabled = true
	)

	tween.tween_interval(0.15)
	tween.tween_property(hand, "rotation_degrees", 0, 0.2)
	tween.parallel().tween_property(hand, "position:x", current_base_x, 0.2)

	await tween.finished
	is_attacking = false

func update_hand_animation():
	if is_dead or is_attacking: return

	hand.position.x = HAND_BASE_X
	var wave_speed = 0.005 if velocity.x != 0 else 0.006
	var wave_amp = 1.0 if velocity.x != 0 else 1.5
	hand.position.y = HAND_BASE_Y + sin(Time.get_ticks_msec() * wave_speed) * wave_amp

func handle_ai_movement(dist, _delta):
	if is_hit or is_dead: return

	var target_speed = 0.0
	var diff_x = target.global_position.x - global_position.x if target else 0.0
	var diff_y = abs(global_position.y - target.global_position.y) if target else 0.0

	if current_state == State.CHASE:
		if dist <= attack_range and diff_y < 25.0:
			velocity.x = move_toward(velocity.x, 0, speed_run * 0.1)
			target_speed = 0
			if not is_attacking:
				sprite.play("idle")
				if can_attack:
					perform_ai_attack()
		else:
			if not is_attacking:
				if abs(diff_x) > attack_range * 0.8:
					target_speed = (1 if diff_x > 0 else -1) * speed_run
					sprite.play("run")
				else:
					target_speed = 0
					sprite.play("idle")

			if is_on_wall() and is_on_floor() and not is_attacking:
				if abs(diff_x) > 30.0:
					check_for_jump()

	elif current_state == State.PATROL:
		if is_patrol_idle:
			target_speed = 0
			sprite.play("idle")
			
			# [NOWE] Jeśli stoisz, bo była krawędź, a timer się skończył...
			if patrol_idle_timer <= 0:
				is_patrol_idle = false
				# Nie musimy tu zmieniać patrol_dir, bo zrobiliśmy to w momencie uderzenia w krawędź
		else:
			if is_edge_ahead():
				# 1. Odwróć kierunek od razu
				patrol_dir *= -1
				# 2. Zatrzymaj go gwałtownie
				velocity.x = 0
				target_speed = 0
				# 3. Włącz krótki odpoczynek
				is_patrol_idle = true
				patrol_idle_timer = 0.6 
				sprite.play("idle")
				# 4. AKTUALIZACJA WIZUALNA: odwróć postać natychmiast
				sprite.flip_h = patrol_dir < 0
				flip_hand(patrol_dir)
				return # Ważne: wychodzimy, żeby nie nadpisać target_speed poniżej

			# --- Logika limitu dystansu (patrol_radius) ---
			var dist_from_start = global_position.x - start_position.x
			var beyond_limit = (patrol_dir == 1 and dist_from_start >= patrol_radius) or \
							   (patrol_dir == -1 and dist_from_start <= -patrol_radius)

			if beyond_limit:
				patrol_dir *= -1
				is_patrol_idle = true
				patrol_idle_timer = 0.5
				sprite.flip_h = patrol_dir < 0
				flip_hand(patrol_dir)
			else:
				target_speed = patrol_dir * speed_walk
				sprite.play("walk")
				if is_on_wall() and is_on_floor():
					check_for_jump()

	# Zastosowanie prędkości
	if not is_attacking:
		velocity.x = move_toward(velocity.x, target_speed, speed_run * 0.2)

	# Obracanie sprite'a
	if abs(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0
		flip_hand(1 if velocity.x > 0 else -1)

func is_path_blocked(dir_x: int) -> bool:
	var direction_vec = Vector2(dir_x, 0)
	return test_move(global_transform.translated(Vector2(0, -34)), direction_vec)

func check_for_jump() -> bool:
	var direction = Vector2(get_look_direction(), 0)

	var can_step_over = not test_move(global_transform.translated(Vector2(0, -18)), direction)
	var can_jump_over = not test_move(global_transform.translated(Vector2(0, -34)), direction)

	if can_step_over:
		velocity.y = -220.0
		return true
	elif can_jump_over:
		velocity.y = -300.0
		return true

	return false
func is_edge_ahead() -> bool:
	if not is_on_floor(): return false
	
	var space_state = get_world_2d().direct_space_state
	var look_dir = get_look_direction()
	
	# PUNKT SPRAWDZANIA: Przesunięty o edge_check_dist przed Nekromantę
	# Zaczynamy lekko powyżej stóp (np. -5), żeby promień nie utknął w podłodze na starcie
	var check_x = global_position.x + (look_dir * edge_check_dist)
	var start_p = Vector2(check_x, global_position.y - 5)
	
	# Cel: 25 pikseli w dół od punktu startowego
	var end_p = Vector2(check_x, global_position.y + 20)
	
	var query = PhysicsRayQueryParameters2D.create(start_p, end_p)
	query.exclude = [get_rid()]
	# Ważne: upewnij się, że promień sprawdza odpowiednią warstwę (Collision Mask)
	# query.collision_mask = 1 # Odkomentuj i ustaw odpowiedni bit, jeśli masz osobne warstwy dla podłogi
	
	var result = space_state.intersect_ray(query)
	
	# Jeśli promień nie uderzył w nic (result jest pusty) -> PRZEPAŚĆ
	return result.is_empty()
func flip_hand(side):
	hand.scale.x = 1
	for child in hand.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.scale.x = abs(child.scale.x) * side
	hand.z_index = -1 if side == -1 else 1

func perform_ai_attack():
	can_attack = false
	perform_attack()
	
	await get_tree().create_timer(1.0).timeout
	# [POPRAWKA] Zabezpieczenie przed wywołaniem po śmierci
	if is_instance_valid(self) and not is_dead:
		can_attack = true

func take_damage(_attacker_pos = Vector2.ZERO):
	if is_dead or is_hit: return

	health -= 1
	is_hit = true
	is_attacking = false

	if sword_collision:
		sword_collision.set_deferred("disabled", true)

	sprite.play("hit")

	var knockback_dir = 1 if sprite.flip_h else -1
	velocity.x = knockback_dir * 200
	velocity.y = -100

	if health <= 0:
		die()
	else:
		sprite.modulate = Color(3.521, 0.0, 0.0, 1.0)
		# [POPRAWKA] Stun wydłużony do 0.35s — był za krótki (0.1s)
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self) and not is_dead:
			sprite.modulate = Color(1, 1, 1)
			is_hit = false

func die():
	if is_dead: return
	is_dead = true
	# [POPRAWKA] Resetujemy wszystkie flagi przy śmierci
	is_hit = false
	is_attacking = false
	velocity = Vector2.ZERO

	sprite.play("death")

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)

	var tween = create_tween()
	tween.tween_property(hand, "rotation_degrees", 150, 0.5)
	tween.parallel().tween_property(hand, "modulate:a", 0.0, 2.0)

	if sprite.is_playing():
		await sprite.animation_finished

	await get_tree().create_timer(2.0).timeout
	queue_free()

func _on_sword_arena_body_entered(body: Node2D) -> void:
	if body == self: return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(global_position)
	elif body.is_in_group("mobs"):
		pass # Demon nie uderza innych mobów
func sync_night_intensity(intensity: float):
	night_level = intensity
