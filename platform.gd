extends Node2D

@onready var prototype_platform = $platformbody
@onready var tile_map_layer: TileMapLayer = $platformLayer

@export var movement_vector: Vector2 = Vector2(0, -100) 
@export var cycle_duration: float = 3.0

var active_platforms = [] 
var time_passed: float = 0.0

func _ready():
	active_platforms.clear()
	setup_platforms()
	
	prototype_platform.hide()
	prototype_platform.get_node("CollisionShape2D").set_deferred("disabled", true)

func setup_platforms():
	var cells = tile_map_layer.get_used_cells()
	
	for cell in cells:
		# Pobieramy ID Atlasu, z którego pochodzi dany kafelek
		var source_id = tile_map_layer.get_cell_source_id(cell)
		var atlas_coords = tile_map_layer.get_cell_atlas_coords(cell)
		
		# Logika: Atlas ID 0 -> Pionowo, Atlas ID 1 -> Poziomo
		if source_id == 0:
			spawn_platform(cell, atlas_coords, "vertical")
		elif source_id == 1:
			spawn_platform(cell, atlas_coords, "horizontal")

func spawn_platform(cell_pos, atlas_coords, type):
	var new_p = prototype_platform.duplicate()
	add_child(new_p)
	
	new_p.show()
	new_p.z_index = 10
	
	var collision = new_p.get_node("CollisionShape2D")
	collision.disabled = false
	collision.one_way_collision = true
	collision.one_way_collision_margin = 1.0 
	
	var is_wide = atlas_coords.x == 1
	var w = 32 if is_wide else 16
	var h = 16
	
	var new_shape = RectangleShape2D.new()
	new_shape.size = Vector2(w, h)
	collision.shape = new_shape

	# Obliczanie pozycji
	var pos_offset = Vector2(8, 0) if is_wide else Vector2(0, 0)
	var target_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(cell_pos)) + pos_offset
	new_p.global_position = target_pos
	
	# Konfiguracja Sprite'a
	var sprite = new_p.get_node("Sprite2D")
	sprite.region_enabled = true
	var source_id = tile_map_layer.get_cell_source_id(cell_pos)
	var source = tile_map_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source:
		sprite.texture = source.texture
	sprite.region_rect = Rect2(atlas_coords.x * 16, atlas_coords.y * 16, w, h)

	active_platforms.append({
		"node": new_p,
		"start_pos": target_pos,
		"time_offset": randf_range(0, 5.0),
		"type": type
	})
	
	tile_map_layer.erase_cell(cell_pos)

func _physics_process(delta):
	if active_platforms.is_empty():
		return
		
	time_passed += delta
	
	for p in active_platforms:
		if is_instance_valid(p.node):
			var current_time = time_passed + p.time_offset
			var factor = (sin(current_time * 2.0 * PI / cycle_duration) + 1.0) / 2.0
			
			var offset = Vector2.ZERO
			if p.type == "vertical":
				offset = movement_vector * factor # Ruch góra-dół (korzysta z Y)
			elif p.type == "horizontal":
				# Bierzemy siłę z Y (np. 100) i wstawiamy ją do X
				offset = Vector2(movement_vector.y, 0) * factor
				
			p.node.global_position = p.start_pos + offset
