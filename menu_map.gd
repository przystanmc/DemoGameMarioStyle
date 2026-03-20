extends Node2D

# Zmienna przechowująca nazwę drzwi, przy których stoi gracz
var current_door: String = ""

func _ready() -> void:
	print("--- Menu główne zainicjowane ---")
	# Upewniamy się, że napisy są ukryte na start
	$DoorStart/Label.hide()
	$DoorShop/Label.hide()
	$DoorSettings/Label.hide()

func _input(event: InputEvent) -> void:
	# Jeśli gracz naciśnie Enter i stoi przy jakichś drzwiach
	if event.is_action_pressed("enter") and current_door != "":
		handle_door_entry()

func handle_door_entry():
	match current_door:
		"start":
			get_tree().change_scene_to_file("res://sceny/main.tscn") # Zmień na swoją nazwę
		"shop":
			print("Sklep jest jeszcze zamknięty!")
			# Tutaj możesz dodać np. mały dymek z napisem "Wkrótce!"
		"settings":
			print("Otwieranie ustawień...")
			get_tree().change_scene_to_file("res://ustawienia.tscn") # Zmień na swoją nazwę

# --- LOGIKA DLA DRZWI START ---
func _on_door_start_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = "start"
		$DoorStart/Label.show()
		print("Gracz przy drzwiach START")

func _on_door_start_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = ""
		$DoorStart/Label.hide()

# --- LOGIKA DLA DRZWI SKLEP ---
func _on_door_shop_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = "shop"
		$DoorShop/Label.show()
		print("Gracz przy drzwiach SKLEP")

func _on_door_shop_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = ""
		$DoorShop/Label.hide()

# --- LOGIKA DLA DRZWI USTAWIENIA ---
func _on_door_settings_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = "settings"
		$DoorSettings/Label.show()
		print("Gracz przy drzwiach USTAWIENIA")

func _on_door_settings_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_door = ""
		$DoorSettings/Label.hide()
