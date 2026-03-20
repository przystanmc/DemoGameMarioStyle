extends Node2D

@export var speed: float = 120.0
@export var max_range: float = 200.0

var direction: float = 1.0
var traveled: float = 0.0

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.flip_h = direction < 0
	sprite.play("fly")

	# Szukamy Area2D niezależnie od nazwy węzła
	var area = _find_area()
	if area:
		area.body_entered.connect(_on_body_entered)
	else:
		push_error("Fireball: nie znaleziono węzła Area2D! Sprawdź strukturę sceny.")

func _find_area() -> Area2D:
	# Najpierw szukamy po typie wśród dzieci
	for child in get_children():
		if child is Area2D:
			return child
	return null

func _physics_process(delta):
	var move = direction * speed * delta
	position.x += move
	traveled += abs(move)

	if traveled >= max_range:
		_destroy()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(global_position)
		_destroy()
	elif body is TileMapLayer or body is TileMap or body.is_in_group("world"):
		_destroy()

func _destroy():
	set_physics_process(false)
	var area = _find_area()
	if area:
		area.monitoring = false
	queue_free()
