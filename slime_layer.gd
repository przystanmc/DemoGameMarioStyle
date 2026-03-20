extends TileMapLayer

@export_group("Sceny Przeciwników")
@export var slime_scene: PackedScene
@export var slime_green_scene: PackedScene # <--- NOWE
@export var ghost_scene: PackedScene
@export var demon_scene: PackedScene
@export var skeleton_scene: PackedScene
@export var warlock_scene: PackedScene
@export var necromancer_scene: PackedScene
@export var dragon_scene: PackedScene
@export var devil_scene: PackedScene

# --- DANE ATLASU ---
const SOURCE_ID = 0
const COORDS_DEMON = Vector2i(0, 0)
const COORDS_NECROMANCER = Vector2i(0, 1) # 0,1
const COORDS_SLIME_GREEN = Vector2i(0, 2)  # 0,2 <--- NOWE
const COORDS_SKELETON = Vector2i(1, 0)
const COORDS_GHOST = Vector2i(1, 1)
const COORDS_SLIME = Vector2i(1, 2)
const COORDS_WARLOCK = Vector2i(2, 0)
const COORDS_DRAGON = Vector2i(2, 1)       # 2,1
const COORDS_DEVIL = Vector2i(3, 0)        # 3,0

func _ready():
	call_deferred("spawn_entities")

func spawn_entities():
	var cells = get_used_cells()
	var counts = {
		"Demons": 0, "Skeletons": 0, "Warlocks": 0, "Ghosts": 0, 
		"Slimes": 0, "Slimes Green": 0, "Necromancers": 0, "Dragons": 0, "Devils": 0
	}

	for cell in cells:
		var atlas_coords = get_cell_atlas_coords(cell)
		var source_id = get_cell_source_id(cell)
		
		if source_id != SOURCE_ID:
			continue

		var new_obj = null

		# LOGIKA WYBORU
		match atlas_coords:
			COORDS_DEMON:
				if demon_scene:
					new_obj = demon_scene.instantiate()
					counts["Demons"] += 1
			COORDS_SKELETON:
				if skeleton_scene:
					new_obj = skeleton_scene.instantiate()
					counts["Skeletons"] += 1
			COORDS_WARLOCK:
				if warlock_scene:
					new_obj = warlock_scene.instantiate()
					counts["Warlocks"] += 1
			COORDS_GHOST:
				if ghost_scene:
					new_obj = ghost_scene.instantiate()
					counts["Ghosts"] += 1
			COORDS_SLIME:
				if slime_scene:
					new_obj = slime_scene.instantiate()
					counts["Slimes"] += 1
			COORDS_SLIME_GREEN: # <--- NOWY PRZYPADEK
				if slime_green_scene:
					new_obj = slime_green_scene.instantiate()
					counts["Slimes Green"] += 1
			COORDS_NECROMANCER:
				if necromancer_scene:
					new_obj = necromancer_scene.instantiate()
					counts["Necromancers"] += 1
			COORDS_DRAGON:
				if dragon_scene:
					new_obj = dragon_scene.instantiate()
					counts["Dragons"] += 1
			COORDS_DEVIL:
				if devil_scene:
					new_obj = devil_scene.instantiate()
					counts["Devils"] += 1

		# Dodawanie do świata
		if new_obj:
			var global_pos = to_global(map_to_local(cell))
			get_parent().add_child(new_obj)
			
			if new_obj.has_method("initialize_position"):
				new_obj.initialize_position(global_pos)
			else:
				new_obj.global_position = global_pos
				
			erase_cell(cell)

	print("Spawnowanie zakończone! Podsumowanie: ", counts)
