extends Node2D

@onready var sprite = $Sprite2D
@onready var area = $Area2D

# Konfiguracja animacji
var frame_count = 12       # Twoje 192 / 16 = 12 klatek
var fps = 12.0             # Prędkość animacji (klatki na sekundę)
var current_frame = 0.0    # Licznik klatek (float dla płynności obliczeń)

func _ready():
	# Konfiguracja Sprite2D dla Twojego paska 192x16
	sprite.hframes = frame_count
	sprite.vframes = 1
	sprite.frame = 0
	
	# Podłączenie sygnału wejścia w Area2D
	area.body_entered.connect(_on_body_entered)

func _process(delta):
	# Animacja w kodzie:
	current_frame += delta * fps
	
	# Resetowanie licznika po dojściu do końca (pętla)
	if current_frame >= frame_count:
		current_frame = 0.0
		
	# Ustawienie aktualnej klatki na Sprite
	sprite.frame = int(current_frame)



func collect(player: Node2D):
	print("Zabrano monetę!")
	
	# Wywołujemy funkcję add_coin u gracza
	if player.has_method("add_coin"):
		player.add_coin()
	
	queue_free() # Moneta znika po przekazaniu punktu

func _on_body_entered(body: Node2D) -> void:
	# Sprawdzamy czy to gracz wszedł w obszar Area2D
	if body.is_in_group("player"):
		collect(body) # Przekazujemy obiekt gracza do funkcji collect
