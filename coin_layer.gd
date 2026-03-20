extends TileMapLayer

# Przeciągnij swoją scenę monety (.tscn) tutaj w Inspektorze
@export var coin_scene: PackedScene 

func _ready():
	# Czekamy na załadowanie silnika
	await get_tree().process_frame
	
	if not coin_scene:
		print("UWAGA: Nie przypisano sceny monety do warstwy kafelków!")
		return
		
	setup_coins()

func setup_coins():
	# Pobieramy wszystkie kafelki narysowane na TEJ warstwie
	var cells = get_used_cells()
	
	for cell in cells:
		spawn_coin(cell)

func spawn_coin(cell_pos):
	var new_coin = coin_scene.instantiate()
	
	# Dodajemy monetę do nadrzędnego węzła (Level), 
	# żeby monety nie zniknęły, gdybyśmy wyłączyli całą warstwę
	get_parent().add_child.call_deferred(new_coin)
	
	# Obliczamy pozycję kafelka i zamieniamy na globalną
	var target_pos = to_global(map_to_local(cell_pos))
	new_coin.global_position = target_pos
	
	# Usuwamy obrazek-znacznik z mapy
	erase_cell(cell_pos)
