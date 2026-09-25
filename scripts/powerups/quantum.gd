extends PowerUp
## Mystery orb: PowerUpManager.collect() swaps it for a random other power-up.


func _init() -> void:
	id = &"quantum"
	display_name = "QUANTUM"
	tagline = "a random power-up"
	glyph = "?"
	color = Color(2.2, 2.2, 2.2)
	duration = 0.0
