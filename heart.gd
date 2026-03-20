extends Control

# Odwołania do Twoich węzłów
@onready var sprite_full = $heart_normal_full
@onready var sprite_half = $heart_normal_half
@onready var sprite_spawn_full = $heart_normal_spawn_full
@onready var sprite_spawn_half = $heart_normal_spawn_half
@onready var sprite_blink_full = $heart_normal_blink_full
@onready var sprite_blink_half = $heart_normal_blink_half
@onready var heart_empty = $heart_empty
@onready var heart_empty_spawn = $heart_empty_spawn
@onready var heart_highlight_layer = $heart_highlight_layer

func _ready():
	hide_all()

func hide_all():
	for child in get_children():
		if child is Sprite2D:
			child.visible = false

func update_heart(type: String):
	hide_all()
	if heart_empty: heart_empty.visible = true
	
	match type:
		"full":
			sprite_full.visible = true
			if heart_highlight_layer: heart_highlight_layer.visible = true
		"half":
			sprite_half.visible = true
		"empty":
			pass

func animate_spawn():
	hide_all()
	if heart_empty: heart_empty.visible = true
	sprite_spawn_full.visible = true
	sprite_spawn_full.hframes = 14
	
	for i in range(14):
		sprite_spawn_full.frame = i
		await get_tree().create_timer(0.04).timeout
	update_heart("full")

func animate_deplete(to_empty: bool):
	hide_all()
	if heart_empty: heart_empty.visible = true
	
	# Wybór animacji mrugania
	var anim = sprite_blink_full if to_empty else sprite_blink_half
	anim.visible = true
	anim.hframes = 3
	
	for i in range(3):
		anim.frame = i
		await get_tree().create_timer(0.08).timeout
	
	update_heart("empty" if to_empty else "half")
	
# Heart.gd

func animate_restore_half():
	hide_all()
	if heart_empty: heart_empty.visible = true
	
	# Używamy sprite_spawn_half (zakładając, że ma 14 klatek jak full)
	if sprite_spawn_half:
		sprite_spawn_half.visible = true
		sprite_spawn_half.hframes = 14
		
		for i in range(14):
			sprite_spawn_half.frame = i
			await get_tree().create_timer(0.03).timeout # Trochę szybciej niż spawn
	
	update_heart("half")

# Opcjonalnie: animacja z half do full
func animate_restore_full():
	hide_all()
	if heart_empty: heart_empty.visible = true
	
	# Używamy standardowego spawnu, bo on buduje całe serce
	sprite_spawn_full.visible = true
	sprite_spawn_full.hframes = 14
	
	for i in range(14):
		sprite_spawn_full.frame = i
		await get_tree().create_timer(0.03).timeout
	
	update_heart("full")
