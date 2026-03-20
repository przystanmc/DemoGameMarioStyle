extends CanvasLayer

@onready var health_bar = $Control/HealthBar
@onready var coin_label = $Control2/CoinContainer/CoinCount
@onready var boost_label = $Control/BoostContainer/BoostTime
@onready var boost_icon = $Control/BoostContainer/BoostIcon
@onready var clock_label = $Control/ClockLabel

# Diament
@onready var diamond_icon = $Control2/GemContainer/IconControl/DiamondIcon
@onready var diamond_label = $Control2/GemContainer/DiamondCount

# Szmaragd
@onready var emerald_icon = $Control2/GemContainer2/IconControl/EmeraldIcon
@onready var emerald_label = $Control2/GemContainer2/EmeraldCount

@onready var dialogue_container = $DialogueContainer
@onready var dialogue_label = $DialogueContainer/VBoxContainer/DialogueLabel
@onready var name_label = $DialogueContainer/VBoxContainer/NameLabel

var current_dialogue_queue = []
var dialogue_index = 0
const TILE_SIZE = 16

func _ready():
	add_to_group("ui")
	# Ukrywamy UI gemów na starcie, ale będą gotowe do pokazania
	if diamond_icon:
		diamond_icon.play("default") # lub nazwa Twojej animacji świecenia
	if emerald_icon:
		emerald_icon.play("default")
	if dialogue_container: dialogue_container.visible = false
	
	update_coins(0)
	if boost_label: boost_label.get_parent().visible = false

# --- LOGIKA GEMÓW (POPRAWIONA) ---

func update_gem_ui(type: int, amount: int, incoming_frames: SpriteFrames = null, animation_name: String = ""):
	var current_label: Label = null
	var current_icon: AnimatedSprite2D = null
	var current_container: Control = null 
	
	match type:
		0: # Diament
			current_label = diamond_label
			current_icon = diamond_icon
			current_container = $Control2/GemContainer
		1: # Szmaragd
			current_label = emerald_label
			current_icon = emerald_icon
			current_container = $Control2/GemContainer2

	# 1. WYMUSZAMY WIDOCZNOŚĆ KONTENERA
	if current_container:
		current_container.visible = true
	
	# 2. AKTUALIZACJA TEKSTU
	if current_label:
		current_label.text = str(amount)

	# 3. MAGIA IKONY (Naprawa błędu guzika)
	if current_icon:
		if incoming_frames != null:
			# Jeśli zbierasz z mapy - ustaw klatki i graj "take" (od tyłu)
			current_icon.sprite_frames = incoming_frames
			if incoming_frames.has_animation("take"):
				_play_take_animation(current_icon, animation_name)
			else:
				current_icon.play("shine")
		else:
			# KLIKNIĘCIE GUZIKA (brak incoming_frames)
			# Jeśli ikona jest pusta, spróbujmy pobrać klatki z oryginału na mapie
			if current_icon.sprite_frames == null:
				var player = get_tree().get_first_node_in_group("player")
				if player and "gem_scene" in player and player.gem_scene:
					var temp = player.gem_scene.instantiate()
					# Szukamy klatek w odpowiednim dziecku gema (z Twojego kodu Gems.gd)
					var source_node_name = "Diamond" if type == 0 else "Emerald"
					var source_node = temp.get_node_or_null(source_node_name)
					if source_node and source_node is AnimatedSprite2D:
						current_icon.sprite_frames = source_node.sprite_frames
					temp.queue_free()
			
			# Odtwórz animację, jeśli już mamy jakieś klatki
			# ... (reszta kodu bez zmian aż do momentu odtwarzania)

			# Odtwórz animację, jeśli już mamy jakieś klatki
			if current_icon.sprite_frames != null:
				# Sprawdzamy, czy animacja "shine" w ogóle istnieje
				if current_icon.sprite_frames.has_animation("shine"):
					current_icon.play("shine")
				else:
					# Jeśli nie ma "shine", pobierz listę wszystkich animacji 
					# i odpal pierwszą z brzegu (prawdopodobnie "default")
					var all_anims = current_icon.sprite_frames.get_animation_names()
					if all_anims.size() > 0:
						current_icon.play(all_anims[0])
					else:
						print("BŁĄD: SpriteFrames dla gema są całkowicie puste!")

# Pamiętaj o tej samej logice w _play_take_animation

# Funkcja pomocnicza do animacji "take" (żeby kod był czystszy)
func _play_take_animation(icon, anim_name):
	if icon.animation_finished.is_connected(_on_gem_take_finished):
		icon.animation_finished.disconnect(_on_gem_take_finished)
	icon.animation_finished.connect(_on_gem_take_finished.bind(icon, anim_name), CONNECT_ONE_SHOT)
	icon.animation = "take"
	icon.frame = icon.sprite_frames.get_frame_count("take") - 1
	icon.speed_scale = -1.5 
	icon.play()

func _on_gem_take_finished(icon: AnimatedSprite2D, target_anim: String):
	icon.speed_scale = 1.0
	_play_target_animation(icon, target_anim)

func _play_target_animation(icon: AnimatedSprite2D, anim_name: String):
	if icon.sprite_frames == null: return
	
	if anim_name != "" and icon.sprite_frames.has_animation(anim_name):
		icon.play(anim_name)
	else:
		var all_anims = icon.sprite_frames.get_animation_names()
		if all_anims.size() > 0:
			icon.play(all_anims[0])
			
func _input(_event):
	# Używamy globalnego Input, a nie zmiennej event
	if Input.is_action_just_pressed("F11"): 
		toggle_fullscreen()

func toggle_fullscreen():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func update_hp(current, max_hp):
	health_bar.update_health(current, max_hp)
func update_clock(time_val, max_time):
	# Przeliczamy 0-200 na minuty (24h = 1440 min)
	var total_minutes = (time_val / max_time) * 1440.0
	var hours = int(total_minutes / 60)
	var minutes = int(int(total_minutes) % 60)
	
	# Ustawiamy tekst w formacie 00:00
	clock_label.text = "%02d:%02d" % [hours, minutes]
func update_coins(amount):
	coin_label.text = str(amount)

func show_boost(time_left, atlas_coords: Vector2i = Vector2i(-1,-1)):
	var container = $Control/BoostContainer
	container.visible = true
	boost_label.text = str(snapped(time_left, 0.1)) + "s"
	
	if atlas_coords != Vector2i(-1, -1):
		var region = Rect2(
			atlas_coords.x * TILE_SIZE, 
			atlas_coords.y * TILE_SIZE, 
			TILE_SIZE, 
			TILE_SIZE
		)
		
		if boost_icon:
			boost_icon.region_rect = region
			# WYMUSZAMY WIDOCZNOŚĆ I SKALĘ W KODZIE (Dla pewności)
			boost_icon.visible = true
			boost_icon.scale = Vector2(3, 3) # Powiększamy ikonkę 3x
			boost_icon.z_index = 10 # Wypychamy przed inne elementy UI
	
	if time_left <= 0:
		container.visible = false
# W game_ui.gd


func start_dialogue(data):
	current_dialogue_queue = data
	dialogue_index = 0
	dialogue_container.visible = true
	display_current_line()

func advance_dialogue():
	dialogue_index += 1
	if dialogue_index < current_dialogue_queue.size():
		display_current_line()
	else:
		hide_dialogue()

func display_current_line():
	var line_info = current_dialogue_queue[dialogue_index] # Pobiera [Imię, Tekst]
	name_label.text = line_info[0]
	dialogue_label.text = line_info[1]
	
	# Efekt maszynopisania
	dialogue_label.visible_ratio = 0.0
	var t = create_tween()
	t.tween_property(dialogue_label, "visible_ratio", 1.0, 0.5)

func hide_dialogue():
	if dialogue_container:
		dialogue_container.visible = false
	current_dialogue_queue = []
