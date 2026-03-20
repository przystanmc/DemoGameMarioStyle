extends CharacterBody2D

@onready var sprite = $FlipRoot/Sprite2D
@onready var anim = $AnimationPlayer

@export var horizontal_speed := 30.0
@export var horizontal_range := 60.0
@export var vertical_amplitude := 10.0
@export var vertical_speed := 2.0

# Aktywne od 16:00 (1000) do 5:00 (312.5) — odwrotnie niż motyle
const ACTIVE_TIME_START := 1000.0
const ACTIVE_TIME_END   := 312.5

const WALL_CHECK_DIST = 10.0

var _speed: float
var _range: float
var _amplitude: float
var _vert_speed: float

var start_pos: Vector2
var time_passed := 0.0
var direction := 1
var is_initialized := false
var _day_manager: Node = null
var _tilemap: TileMapLayer = null
var _wall_layer_index := -1

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	anim.play("fly")

	var managers = get_tree().get_nodes_in_group("day_manager")
	if managers.size() > 0:
		_day_manager = managers[0]

func initialize_butterfly(pos: Vector2, tilemap: TileMapLayer = null):
	_tilemap = tilemap
	global_position = pos
	start_pos = pos
	is_initialized = true

	# Cache indeksu "wall" — identycznie jak u motyli
	if _tilemap and _tilemap.tile_set:
		for i in range(_tilemap.tile_set.get_custom_data_layers_count()):
			if _tilemap.tile_set.get_custom_data_layer_name(i) == "wall":
				_wall_layer_index = i
				break

	# Losowość — każdy świetlik inny
	_speed      = horizontal_speed   * randf_range(0.6, 1.4)
	_range      = horizontal_range   * randf_range(0.5, 1.5)
	_amplitude  = vertical_amplitude * randf_range(0.4, 1.6)
	_vert_speed = vertical_speed     * randf_range(0.5, 1.8)

	time_passed = randf_range(0.0, TAU)
	direction = 1 if randf() > 0.5 else -1

	if anim:
		anim.speed_scale = randf_range(0.8, 1.3)

	_update_sprite_flip()

func _physics_process(delta):
	if not is_initialized:
		return

	if not _is_active_time():
		visible = false
		return
	visible = true

	# OŚ X — odbicie od ściany
	if _is_wall_tile(Vector2(direction * WALL_CHECK_DIST, 0)):
		direction *= -1
		_update_sprite_flip()
		global_position.x += direction * (WALL_CHECK_DIST + 1.0)

	var x_dist = global_position.x - start_pos.x
	if x_dist > _range and direction == 1:
		direction = -1
		_update_sprite_flip()
	elif x_dist < -_range and direction == -1:
		direction = 1
		_update_sprite_flip()

	global_position.x += direction * _speed * delta

	# OŚ Y — sinusoida bezpośrednio
	time_passed += delta * _vert_speed
	global_position.y = start_pos.y + sin(time_passed) * _amplitude

func _is_active_time() -> bool:
	if _day_manager == null:
		return true
	var t = _day_manager.current_time
	# Aktywne od 16:00 do końca doby I od początku do 5:00
	# czyli: t >= 1000 LUB t < 312.5
	return t >= ACTIVE_TIME_START or t < ACTIVE_TIME_END

func _is_wall_tile(offset: Vector2) -> bool:
	if not is_instance_valid(_tilemap) or _wall_layer_index == -1:
		return false

	var check_pos = global_position + offset
	var tile_pos = _tilemap.local_to_map(_tilemap.to_local(check_pos))

	if _tilemap.get_cell_source_id(tile_pos) != 1:
		return false

	var tile_data = _tilemap.get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false

	return tile_data.get_custom_data_by_layer_id(_wall_layer_index) == true

func _update_sprite_flip():
	if has_node("FlipRoot"):
		$FlipRoot.scale.x = -direction
