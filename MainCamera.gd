extends Camera2D

@export var zoom_speed: float = 0.1
@export var max_zoom: float = 4.0 # Jak blisko możemy podejść
var min_zoom: float = 0.5 # To obliczymy dynamicznie

var limit_rect: Rect2

func _ready():
	await get_tree().process_frame
	setup_camera_bounds()

func setup_camera_bounds():
	var top_left = get_tree().current_scene.find_child("LimitTopLeft", true, false)
	var bottom_right = get_tree().current_scene.find_child("LimitBottomRight", true, false)
	
	if top_left and bottom_right:
		limit_left = top_left.global_position.x
		limit_top = top_left.global_position.y
		limit_right = bottom_right.global_position.x
		limit_bottom = bottom_right.global_position.y
		
		# Tworzymy prostokąt pomocniczy do obliczeń zooma
		limit_rect = Rect2(
			top_left.global_position, 
			bottom_right.global_position - top_left.global_position
		)
		
		calculate_min_zoom()
		
		limit_smoothed = true
		position_smoothing_enabled = true
	else:
		# Reset dla map bez markerów
		wylacz_limity()

func calculate_min_zoom():
	# Obliczamy, jaki zoom jest potrzebny, żeby wypełnić ekran obszarem limitu
	var screen_size = get_viewport_rect().size
	var zoom_x = screen_size.x / limit_rect.size.x
	var zoom_y = screen_size.y / limit_rect.size.y
	
	# Wybieramy większy zoom, żeby obraz zawsze zakrywał tło
	min_zoom = max(zoom_x, zoom_y)
	
	# Jeśli obecny zoom jest mniejszy niż dopuszczalny, naprawiamy go
	if zoom.x < min_zoom:
		zoom = Vector2(min_zoom, min_zoom)

# --- W Twoim skrypcie Camera2D.gd ---

func _input(event):
	var old_zoom = zoom # Zapamiętujemy stary zoom do porównania
	
	if event.is_action_pressed("zoom_in"):
		zoom += Vector2(zoom_speed, zoom_speed)
	
	if event.is_action_pressed("zoom_out"):
		if zoom.x > min_zoom:
			# --- NAPRAWA START ---
			# 1. Tymczasowo wyłączamy wygładzanie
			position_smoothing_enabled = false
			# --- NAPRAWA KONIEC ---
			
			zoom -= Vector2(zoom_speed, zoom_speed)
	
	# Clamp zoomu (to samo co wcześniej)
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = clamp(zoom.y, min_zoom, max_zoom)
	
	# --- NAPRAWA CD. ---
	# Jeśli zoom faktycznie się zmienił (oddaliliśmy się)
	if zoom != old_zoom and event.is_action_pressed("zoom_out"):
		# 2. Wymuszamy natychmiastową aktualizację pozycji (bez wygładzania)
		# To sprawia, że krawędź kamery "teleportuje się" na linię markera.
		force_update_scroll()
		
		# 3. Włączamy wygładzanie z powrotem dla płynnego ruchu
		# Czekamy jedną klatkę, żeby teleport się wykonał
		await get_tree().process_frame
		position_smoothing_enabled = true
	# --- NAPRAWA KONIEC CD ---
func wylacz_limity():
	# Reset do domyślnych ogromnych wartości
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
	position_smoothing_enabled = false
