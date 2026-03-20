extends Node2D

@onready var anim_player = $AnimationPlayer
@onready var sprite_sign = $Sprite2D
@onready var welcome_root = $Welcome
@onready var sprite_key = $keyboard
@onready var sprite_press = $keyboard_press
@onready var label = $Control/Label 

var roll_text = "Nacisnij Shift zeby sie turlac!"
var is_closing = false

# TUTAJ BYŁ BŁĄD - dodajemy tę zmienną:
var welcome_text = "Witaj graczu! Pojawiles sie na samym dole. Wskakuj do gory i ratuj ksiezniczke!"

var blink_speed = 0.4  
var time_passed = 0.0

# Zmień początek skryptu HintIcon
var mode = "sign":
	set(value):
		mode = value
		if is_node_ready(): # Jeśli węzeł już jest w drzewie, odśwież widok
			setup_view()

func _ready():
	# Podłączamy sygnał tylko raz
	if not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)
	
	setup_view()

func setup_view():
	# Ukrywamy wszystko na start
	sprite_sign.visible = false
	welcome_root.visible = false
	sprite_key.visible = false
	sprite_press.visible = false
	
	match mode:
		"sign_jump": # Pokazuje dymek, ale Label zostanie pusty
			welcome_root.visible = true
			label.text = "" 
			anim_player.play("appear")
		"sign_roll", "sign2":
			welcome_root.visible = true
			label.text = "" 
			anim_player.play("appear")
		"bottle":
			sprite_key.visible = true
		"sign":
			sprite_sign.visible = true
			anim_player.play("appear")

func _on_animation_finished(anim_name):
	if anim_name == "appear":
		anim_player.play("idle")
		
		# LOGIKA WYBORU TEKSTU
		if mode == "sign2":
			type_text(welcome_text)
		elif mode == "sign_roll":
			type_text(roll_text)
		# Dla "sign_jump" nic tutaj nie dopisujemy -> Label zostanie pusty
			
	elif anim_name == "disappear":
		queue_free()
			
func _process(delta):
	if mode == "bottle" and not is_closing:
		animate_keyboard_blink(delta)

func animate_keyboard_blink(delta):
	time_passed += delta
	if time_passed >= blink_speed:
		time_passed = 0.0
		sprite_key.visible = !sprite_key.visible
		sprite_press.visible = !sprite_key.visible


func type_text(txt: String):
	if not label: return
	label.text = txt
	label.visible_characters = 0
	var duration = txt.length() * 0.04 
	var tween = create_tween()
	tween.tween_property(label, "visible_characters", txt.length(), duration)

func start_disappearing():
	if is_closing: return
	is_closing = true
	
	# NOWOŚĆ: Natychmiastowe ukrycie tekstu
	if label:
		label.text = "" 
	
	if mode == "bottle":
		queue_free()
	else:
		anim_player.play("disappear")
