extends CharacterBody2D

enum State { IDLE, PATROL, CHASE }
var current_state = State.PATROL

@onready var sprite = $AnimatedSprite2D
@onready var hand = $Hand
@onready var sword_collision = $Hand/Sword/SwordArena/SwordCollision

# --- SYSTEM ŚWIATŁA ---
@onready var light_node = get_node_or_null("TestLight")
var night_level: float = 0.0
var target_energy: float = 0.0
var light_pulse_time: float = 0.0
@export var max_light_energy: float = 0.8

@export var target: Node2D
@export var detect_range := 70.0
@export var attack_range := 15.0

# --- PARAMETRY RUCHU ---
var speed_walk := 40.0
var speed_run := 80.0
var health := 30
var is_attacking := false
var is_dead := false
var can_attack := true

# --- ZMIENNE PATROLU ---
var patrol_dir := 1
var patrol_timer := 0.0
const BLOCK_SIZE = 16.0
const PATROL_DISTANCE = 6 * 16.0
var is_hit := false
const HAND_BASE_X = -6.0
const HAND_BASE_Y = 6.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- DETEKCJA KRAWĘDZI ---
# Przesunięcie poziome punktu startu ray castów (przed postacią)
const EDGE_CHECK_OFFSET = 10.0
# Ray krótki: 1-2 kafelki w dół — jeśli trafia, można skoczyć w dół
const EDGE_JUMP_DEPTH = 32.0
# Ray długi: 3+ kafelki w dół — jeśli NIE trafia, to prawdziwa przepaść
const EDGE_FALL_DEPTH = 56.0

func get_look_direction() -> int:
	return -1 if sprite.flip_h else 1

func _ready():
	add_to_group("knight_lights")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

	if has_node("Slash"):
		$Slash.animation_finished.connect(func(): $Slash.visible = false)
	if has_node("Slash2"):
		$Slash2.animation_finished.connect(func(): $Slash2.visible = false)

	if light_node:
		light_node.enabled = false

func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	_update_light(delta)

	if not is_hit and not is_attacking:
		var dist = 9999.0
		if target:
			dist = global_position.distance_to(target.global_position)

		if dist < detect_range:
			current_state = State.CHASE
		else:
			if current_state == State.CHASE:
				current_state = State.PATROL
				patrol_timer = 2.0

			patrol_timer -= delta
			if patrol_timer <= 0:
				patrol_dir *= -1
				patrol_timer = randf_range(2.0, 4.0)

		handle_ai_movement(dist, delta)

	if is_hit:
		velocity.x = move_toward(velocity.x, 0, speed_run * delta * 10)
		if sprite.animation != "hit":
			sprite.play("hit")

	move_and_slide()
	update_hand_animation()

# --- DETEKCJA KRAWĘDZI ---

# Pomocnicza: rzuca ray w dół z punktu przesuniętego przed postacią
func _cast_ray_down(dir: int, depth: float) -> bool:
	var origin = global_position + Vector2(dir * EDGE_CHECK_OFFSET, 0)
	var query = PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, depth))
	query.exclude = [self]
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

# Zwraca true jeśli podłoga jest w zasięgu krótkiego skoku (1-2 kafelki)
func has_floor_nearby(dir: int) -> bool:
	return _cast_ray_down(dir, EDGE_JUMP_DEPTH)

# Zwraca true jeśli to prawdziwa przepaść (3+ kafelki pustki)
func is_cliff_ahead(dir: int) -> bool:
	return not _cast_ray_down(dir, EDGE_FALL_DEPTH)

# Łączna logika dla handle_ai_movement:
# Zwraca: "walk" | "jump_down" | "cliff"
func check_ahead(dir: int) -> String:
	if not is_on_floor():
		return "walk"  # już w powietrzu — nie blokuj
	if has_floor_nearby(dir):
		return "walk"          # podłoga tuż przed/pod — idź normalnie
	if is_cliff_ahead(dir):
		return "cliff"         # przepaść — zawróć
	return "jump_down"         # podłoga w zasięgu skoku — skocz w dół

# --- SYSTEM ŚWIATŁA ---

func sync_night_intensity(intensity: float):
	night_level = intensity

func _update_light(delta):
	if not light_node:
		return
	light_pulse_time += delta * 6.0
	var flicker = sin(light_pulse_time) * 0.08 * night_level
	target_energy = lerp(target_energy, night_level * max_light_energy, 0.05)
	light_node.energy = target_energy + flicker
	light_node.enabled = light_node.energy > 0.05

# --- ATAK ---

func perform_attack():
	is_attacking = true
	var side = get_look_direction()

	var current_base_x = HAND_BASE_X
	var back_x = current_base_x - 3.0 * side
	var target_x = current_base_x + 2.0 * side

	var current_slash = $Slash if side == 1 else $Slash2
	$Slash.visible = false
	$Slash2.visible = false

	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")

	var tween = create_tween()

	tween.tween_property(hand, "rotation_degrees", -85.0 * side, 0.1)
	tween.parallel().tween_property(hand, "position:x", back_x, 0.1)

	tween.tween_callback(func():
		if current_slash:
			current_slash.visible = true
			current_slash.frame = 0
			current_slash.speed_scale = 10.4
			current_slash.play("Slash")
		if sword_collision:
			sword_collision.disabled = false
	)

	tween.tween_property(hand, "rotation_degrees", 105.0 * side, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hand, "position:x", target_x, 0.18)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y + (1.0 if side == 1 else 0.0), 0.18)

	tween.tween_callback(func():
		if sword_collision:
			sword_collision.disabled = true
	)

	tween.tween_interval(0.17)
	tween.tween_callback(func():
		$Slash.visible = false
		$Slash2.visible = false
	)

	tween.tween_property(hand, "rotation_degrees", 0, 0.2)
	tween.parallel().tween_property(hand, "position:x", current_base_x, 0.2)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y, 0.2)

	await tween.finished
	is_attacking = false

func perform_ai_attack():
	can_attack = false
	await perform_attack()
	await get_tree().create_timer(0.6).timeout
	if not is_dead:
		can_attack = true

func update_hand_animation():
	if is_dead or is_attacking:
		return
	hand.position.x = HAND_BASE_X
	var wave_speed = 0.005 if velocity.x != 0 else 0.006
	var wave_amp = 1.0 if velocity.x != 0 else 1.5
	hand.position.y = HAND_BASE_Y + sin(Time.get_ticks_msec() * wave_speed) * wave_amp

func handle_ai_movement(dist, _delta):
	if is_hit or is_dead:
		return

	var diff_x = target.global_position.x - global_position.x if target else 0.0
	var diff_y = abs(global_position.y - target.global_position.y) if target else 0.0

	if current_state == State.CHASE:
		if dist <= attack_range and diff_y < 25.0:
			velocity.x = move_toward(velocity.x, 0, speed_run * 0.1)
			if not is_attacking:
				sprite.play("idle")
				if can_attack:
					perform_ai_attack()
		else:
			if not is_attacking:
				if abs(diff_x) > attack_range * 0.8:
					var move_dir = 1 if diff_x > 0 else -1
					var ahead = check_ahead(move_dir)
					match ahead:
						"walk":
							velocity.x = move_toward(velocity.x, move_dir * speed_run, speed_run * 0.2)
							sprite.play("run")
						"jump_down":
							# Podłoga w zasięgu — skocz w dół żeby ścigać gracza
							velocity.x = move_toward(velocity.x, move_dir * speed_run, speed_run * 0.2)
							if is_on_floor():
								velocity.y = -80.0  # Minimalny impuls, grawitacja zrobi resztę
							sprite.play("run")
						"cliff":
							# Prawdziwa przepaść — stój
							velocity.x = move_toward(velocity.x, 0, speed_run * 0.2)
							sprite.play("idle")
				else:
					velocity.x = move_toward(velocity.x, 0, speed_run * 0.2)
					sprite.play("idle")

			if is_on_wall() and is_on_floor() and not is_attacking:
				if abs(diff_x) > 30.0:
					check_for_jump()

	elif current_state == State.PATROL:
		var ahead = check_ahead(patrol_dir)
		match ahead:
			"walk":
				velocity.x = move_toward(velocity.x, patrol_dir * speed_walk, speed_run * 0.2)
				sprite.play("walk")
			"jump_down":
				# Schodki w dół — po prostu idź, grawitacja przeprowadzi
				velocity.x = move_toward(velocity.x, patrol_dir * speed_walk, speed_run * 0.2)
				sprite.play("walk")
			"cliff":
				# Przepaść — zawróć
				patrol_dir *= -1
				patrol_timer = randf_range(1.0, 2.0)
				velocity.x = move_toward(velocity.x, 0, speed_run * 0.2)
				sprite.play("idle")

		if is_on_wall() and is_on_floor():
			check_for_jump()

	if abs(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0
		flip_hand(1 if velocity.x > 0 else -1)

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

func flip_hand(side):
	for child in hand.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.scale.x = side
	hand.z_index = -1 if side == -1 else 1

# --- OBRAŻENIA I ŚMIERĆ ---

func take_damage(_attacker_pos = Vector2.ZERO):
	if is_dead or is_hit:
		return

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
		sprite.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_dead or not is_instance_valid(self):
			return
		sprite.modulate = Color(1, 1, 1)
		is_hit = false

func die():
	if is_dead:
		return
	is_dead = true
	velocity.x = 0
	sprite.play("death")

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if light_node:
		var light_tween = create_tween()
		light_tween.tween_property(light_node, "energy", 0.0, 0.4)
		light_tween.tween_callback(func():
			if is_instance_valid(light_node):
				light_node.enabled = false
		)

	var tween = create_tween()
	tween.tween_property(hand, "rotation_degrees", 150, 0.5)
	tween.parallel().tween_property(hand, "modulate:a", 0.0, 2.0)

	if sprite.is_playing():
		await sprite.animation_finished
	if not is_instance_valid(self):
		return

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return

	queue_free()

func _on_sword_arena_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(global_position)
