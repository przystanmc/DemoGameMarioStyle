extends CharacterBody2D

@export var coin_scene: PackedScene 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_destroyed = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	move_and_slide()

func take_damage(_amount = 0):
	if is_destroyed: return
	is_destroyed = true
	
	# 1. Wyłączamy kolizję tylko na warstwie, którą bije rycerz (np. layer 1)
	# Ale zostawiamy maskę, żeby skrzynia nie przepadła przez podłogę w trakcie animacji
	set_collision_layer_value(1, false)
	
	# 2. Odpalenie animacji
	if has_node("AnimatedSprite2D"):
		var anim = $AnimatedSprite2D
		anim.play("destroy") 
	
	# 3. Szansa na monetę
	if randf() > 0.5:
		call_deferred("spawn_coin")

# 4. To wywoła się automatycznie, gdy animacja "destroy" dojdzie do końca
func _on_animated_sprite_2d_animation_finished():
	if $AnimatedSprite2D.animation == "destroy":
		queue_free() # Dopiero teraz skrzynia znika, a te nad nią spadają

func spawn_coin():
	if coin_scene:
		var coin = coin_scene.instantiate()
		get_parent().add_child(coin)
		coin.global_position = global_position
		if "velocity" in coin:
			coin.velocity = Vector2(randf_range(-40, 40), -150)
