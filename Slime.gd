extends CharacterBody2D

@onready var anim_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var light_node = $TestLight

var player = null
var is_active = false
var is_dead = false
var detection_range = 128.0
var _detection_range_sq: float

var night_level: float = 0.0
var target_energy: float = 0.0
var light_pulse_time: float = 0.0
@export var max_light_energy: float = 0.6

func _ready():
	_detection_range_sq = detection_range * detection_range
	player = get_tree().get_first_node_in_group("player")
	anim_player.play("init")
	if light_node:
		light_node.enabled = false

func _physics_process(delta):
	if is_dead:
		return

	if light_node and is_active:
		light_pulse_time += delta * 4.0
		target_energy = lerp(target_energy, night_level * max_light_energy, 0.05)

		# Poprawka #2: flicker skalowany przez night_level — w dzień nie mruga
		var flicker = sin(light_pulse_time) * 0.1 * night_level
		light_node.energy = target_energy + flicker

		# Poprawka #1: światło włącza się tylko gdy jest wystarczająco ciemno
		light_node.enabled = light_node.energy > 0.05

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	if not is_active:
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq <= _detection_range_sq:
			activate_slime()

func activate_slime():
	if not is_instance_valid(player):
		return
	is_active = true
	anim_player.play("up")
	# Poprawka #1: NIE włączamy światła tutaj — _physics_process zrobi to
	# automatycznie gdy night_level będzie wystarczająco wysokie

func sync_night_intensity(intensity: float):
	night_level = intensity

# Używana przy poolingu obiektów — wywołaj zamiast _ready() przy ponownym użyciu
func _setup_slime():
	player = get_tree().get_first_node_in_group("player")
	is_active = false
	is_dead = false
	_detection_range_sq = detection_range * detection_range
	night_level = 0.0
	target_energy = 0.0
	light_pulse_time = 0.0
	if light_node:
		light_node.energy = 0.0
		light_node.enabled = false
	if anim_player:
		anim_player.play("init")

func die():
	if is_dead:
		return
	is_dead = true

	if light_node:
		var tween = create_tween()
		tween.tween_property(light_node, "energy", 0.0, 0.3)
		tween.tween_callback(func():
			if is_instance_valid(light_node):
				light_node.enabled = false
		)

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", false)
		$Area2D.set_deferred("monitorable", false)
	anim_player.play("kill")

func take_damage(_attacker_pos = Vector2.ZERO):
	if not is_dead:
		die()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "kill":
		queue_free()
	elif anim_name == "up":
		anim_player.play("idle")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		await get_tree().physics_frame
		if not is_instance_valid(body) or is_dead:
			return
		if body.get("is_attacking") == true:
			return

		var is_falling = body.velocity.y > 50
		var is_above = body.global_position.y < (global_position.y - 4.8)

		if is_falling and is_above:
			take_damage(body.global_position)
			body.velocity.y = -300
		else:
			if body.has_method("take_damage"):
				body.take_damage(global_position)
