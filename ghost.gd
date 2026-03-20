extends CharacterBody2D

# --- KONFIGURACJA ---
const SPEED = 50.0
const IDLE_TIME_WALL = 2.0  
const TILE_SIZE = 16.0
const WANDER_RADIUS = 10 * TILE_SIZE

# --- STANY ---
enum State { WAKE, IDLE, RUN, RETURN, IDLE_CENTER, HIT, DEATH }
var current_state = State.WAKE
var direction = Vector2.ZERO
var is_dead = false
var idle_timer = 0.0
var start_x := 0.0

# --- SYSTEM ŚWIATŁA ---
var night_level: float = 0.0
var target_energy: float = 0.0
var light_pulse_time: float = 0.0
@export var max_light_energy: float = 0.7 

@onready var sprite = $AnimatedSprite2D
@onready var light_node = get_node_or_null("AnimatedSprite2D/TestLight")

func _ready():
	add_to_group("knight_lights")
	# Zabezpieczenie, jeśli start_x nie zostanie ustawione przez spawner
	if start_x == 0.0:
		start_x = position.x
	
	floor_snap_length = 0.0
	set_state(State.WAKE)

func _physics_process(delta):
	# 1. WIZUALIA (Kołysanie i Światło)
	if not is_dead:
		sprite.position.y = sin(Time.get_ticks_msec() * 0.005) * 5.0
		_update_light(delta)

	# 2. BLOKADY RUCHU
	if current_state == State.DEATH or current_state == State.HIT or current_state == State.WAKE:
		move_and_slide()
		return

	# 3. MASZYNA STANÓW
	match current_state:
		State.RUN:
			if _is_at_limit():
				set_state(State.RETURN)
			else:
				velocity = direction * SPEED
				sprite.play("run")
				sprite.flip_h = direction.x < 0
				
				if is_on_wall():
					set_state(State.IDLE) 

		State.RETURN:
			var dist_to_start = start_x - position.x
			if abs(dist_to_start) < 4.0:
				position.x = start_x
				set_state(State.IDLE_CENTER)
			else:
				var dir_to_center = sign(dist_to_start)
				velocity = Vector2(dir_to_center * SPEED, 0)
				sprite.play("run")
				sprite.flip_h = dir_to_center < 0
				
				if is_on_wall():
					set_state(State.IDLE_CENTER)

		State.IDLE, State.IDLE_CENTER:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta)
			sprite.play("idle")
			idle_timer -= delta
			if idle_timer <= 0.0:
				if current_state == State.IDLE:
					set_state(State.RETURN) 
				else:
					_choose_direction()

	move_and_slide()

# --- SYSTEM ŚWIATŁA ---

func sync_night_intensity(intensity: float):
	night_level = intensity

func _update_light(delta):
	if light_node:
		target_energy = lerp(target_energy, night_level * max_light_energy, 0.05)
		light_pulse_time += delta * 8.0
		var flicker = sin(light_pulse_time) * 0.05
		light_node.energy = target_energy + (flicker * night_level)
		light_node.enabled = light_node.energy > 0.01

# --- LOGIKA WALKI ---

func take_damage(_attacker_pos = Vector2.ZERO):
	if is_dead: return
	is_dead = true
	set_state(State.HIT)

func die():
	set_state(State.DEATH)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", false)
		$Area2D.set_deferred("monitorable", false)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		# Mały delay na sprawdzenie fizyki
		await get_tree().physics_frame
		
		# Sprawdzamy czy gracz atakuje mieczem
		if body.get("is_attacking") == true:
			return
			
		# Mechanika skoku na głowę
		var is_falling = body.velocity.y >= -10
		var is_above = body.global_position.y < (global_position.y - 4)
		
		if is_falling and is_above:
			take_damage()
			if body.has_method("jump"): # Jeśli gracz ma funkcję jump
				body.velocity.y = -350
		else:
			# Gracz dotknął ducha bokiem -> otrzymuje obrażenia
			if body.has_method("take_damage"):
				body.take_damage(global_position)

# --- POMOCNICZE ---

func set_state(new_state: State):
	current_state = new_state
	match current_state:
		State.WAKE: sprite.play("wake")
		State.IDLE: 
			idle_timer = IDLE_TIME_WALL
			sprite.play("idle")
		State.IDLE_CENTER: 
			idle_timer = randf_range(1.0, 2.0)
			sprite.play("idle")
		State.HIT: sprite.play("hit")
		State.DEATH: sprite.play("death")

func _is_at_limit() -> bool:
	var dist = position.x - start_x
	return (dist >= WANDER_RADIUS and direction.x > 0) or (dist <= -WANDER_RADIUS and direction.x < 0)

func _choose_direction():
	direction.x = 1.0 if randf() > 0.5 else -1.0
	set_state(State.RUN)

func initialize_position(pos: Vector2):
	global_position = pos
	start_x = position.x

# --- SYGNAŁY ANIMACJI ---

func _on_animated_sprite_2d_animation_finished():
	match sprite.animation:
		"wake":
			_choose_direction()
		"hit":
			die()
		"death":
			queue_free()
