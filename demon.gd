extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var hand = $Hand
@onready var slash_anim = $Slash # Dodaj tę referencję na górze
@onready var sword_collision = $Hand/Sword/SwordArena/SwordCollision

const HAND_BASE_X = -6.0
const HAND_BASE_Y = 6.0

var speed := 120.0
var is_attacking := false
var is_dead := false

func get_look_direction() -> int:
	return -1 if sprite.flip_h else 1
func _ready():
	$Slash.animation_finished.connect(func(): $Slash.visible = false)
	$Slash2.animation_finished.connect(func(): $Slash2.visible = false)
func _physics_process(_delta):
	if is_dead: return

	var dir = Input.get_axis("ui_left", "ui_right")
	if not is_attacking:
		velocity.x = dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.1)

	move_and_slide()

# ---- LOGIKA ODWRACANIA ----
	if not is_attacking:
		if dir != 0:
			var side = 1 if dir > 0 else -1
			sprite.flip_h = dir < 0
			
			# Odwracamy grafikę miecza/dłoni
			# Używamy skali duszka wewnątrz, a nie całej dłoni, żeby nie psuć rotacji
			for child in hand.get_children():
				if child is Sprite2D or child is AnimatedSprite2D:
					# To odwraca obrazek w miejscu, nie zmieniając pozycji dłoni
					child.scale.x = side 
		
		# Ręka za plecami, gdy idziemy w lewo
		hand.z_index = -1 if sprite.flip_h else 1

	# ---- ANIMACJE I POZYCJA ----
	if not is_attacking:
		# Skoro obie strony mają być na -6.0
		hand.position.x = HAND_BASE_X 
		
		# Reszta Twojego kodu (walk/idle/falowanie Y)
		if dir != 0:
			sprite.play("walk")
			hand.position.y = HAND_BASE_Y + sin(Time.get_ticks_msec() * 0.005) * 1.0
		else:
			sprite.play("idle")
			hand.position.y = HAND_BASE_Y + sin(Time.get_ticks_msec() * 0.006) * 1.5
			hand.rotation_degrees = sin(Time.get_ticks_msec() * 0.002) * 2
func perform_attack():
	is_attacking = true
	var side = get_look_direction() 
	
	# --- PARAMETRY ---
	var current_base_x = HAND_BASE_X 
	var back_x = current_base_x + (-4.0 * side)
	var target_x = current_base_x + ((7.0 if side == 1 else 1.0) * side)
	
	# Wybór duszka Slash
	var current_slash = $Slash if side == 1 else $Slash2
	$Slash.visible = false
	$Slash2.visible = false

	# --- TWEEN ---
	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	
	var tween = create_tween()
	
	# KROK 1: ZAMACH
	tween.tween_property(hand, "rotation_degrees", -85.0 * side, 0.1)
	tween.parallel().tween_property(hand, "position:x", back_x, 0.1)
	
	# KROK 2: CIĘCIE (Wyrzut dłoni + WŁĄCZENIE HITBOXA)
	tween.tween_callback(func(): 
		if current_slash:
			current_slash.visible = true
			current_slash.frame = 0
			current_slash.speed_scale = 5.4
			current_slash.play("Slash")
			
		# AKTYWACJA KOLIZJI
		if sword_collision:
			sword_collision.disabled = false
	)
	
	tween.tween_property(hand, "rotation_degrees", 105.0 * side, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hand, "position:x", target_x, 0.18)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y + (1.0 if side == 1 else 0.0), 0.18)
	
	# KONIEC CIĘCIA (WYŁĄCZENIE HITBOXA)
	# Wyłączamy kolizję zaraz po uderzeniu, żeby nie ranić wrogów przy powrocie
	tween.tween_callback(func():
		if sword_collision:
			sword_collision.disabled = true
	)

	# KROK 3: POWRÓT
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
func _input(event):
	if is_dead: return
	if event.is_action_pressed("attack") and not is_attacking:
		perform_attack()

func take_damage():
	if is_dead: return
	sprite.play("hit")
	var tween = create_tween()
	tween.tween_property(hand, "position:x", HAND_BASE_X - 5, 0.1)
	tween.tween_property(hand, "position:x", HAND_BASE_X, 0.1)

func die():
	if is_dead: return
	is_dead = true
	sprite.play("death")
	var tween = create_tween()
	tween.tween_property(hand, "rotation_degrees", 150, 0.3)
	tween.parallel().tween_property(hand, "position:y", HAND_BASE_Y + 10, 0.3)
	set_physics_process(false)
	collision_layer = 0


func _on_sword_arena_body_entered(body: Node2D) -> void:
	# Sprawdzamy czy to przeciwnik (np. ma funkcję take_damage)
	# I upewniamy się, że nie trafiamy samych siebie
	if body.has_method("take_damage") and body != self:
		body.take_damage()
