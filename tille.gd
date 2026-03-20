extends TileMapLayer

@export var firefly_scene: PackedScene
@export var butterfly_scene: PackedScene
@export var chest_scene: PackedScene
@export var butterfly_count := 15
@export var firefly_count := 10

func _ready():
	spawn_insects()
	await get_tree().process_frame
	replace_chests_with_objects()

func replace_chests_with_objects():
	if not chest_scene: return
	var used_tiles = get_used_cells()
	for coords in used_tiles:
		var tile_data = get_cell_tile_data(coords)
		if tile_data and tile_data.get_custom_data("is_chest"):
			var global_pos = to_global(map_to_local(coords))
			set_cell(coords, -1)
			var new_chest = chest_scene.instantiate()
			get_parent().add_child.call_deferred(new_chest)
			new_chest.global_position = global_pos

func spawn_insects():
	var bounds = get_used_rect()
	if bounds.size == Vector2i.ZERO:
		print("BŁĄD: TileMapLayer jest pusty!")
		return

	_create_random_group(butterfly_scene, butterfly_count, bounds, true)
	_create_random_group(firefly_scene, firefly_count, bounds, false)

func _create_random_group(scene: PackedScene, count: int, bounds: Rect2i, is_butterfly: bool):
	if not scene: return

	var spawned = 0
	var attempts = 0

	# $Background ma custom data "wall" — przekazujemy go do owadów
	var background_tilemap = get_parent() as TileMapLayer

	while spawned < count and attempts < 1000:
		attempts += 1
		var rx = randi_range(bounds.position.x, bounds.end.x)
		var ry = randi_range(bounds.position.y, bounds.end.y)
		var r_cell = Vector2i(rx, ry)

		if get_cell_source_id(r_cell) != -1:
			var tile_size = rendering_quadrant_size
			var pos = to_global(map_to_local(r_cell)) + Vector2(0, -tile_size)

			var obj = scene.instantiate()
			get_parent().add_child.call_deferred(obj)

			if is_butterfly:
				var colors = ["blue", "red", "green", "purple"]
				obj.call_deferred("initialize_butterfly", pos, colors.pick_random(), background_tilemap)
			else:
				# Świetlik nie ma color_name — tylko pos i tilemap
				obj.call_deferred("initialize_butterfly", pos, background_tilemap)

			spawned += 1
