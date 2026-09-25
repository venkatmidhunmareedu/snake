extends PowerUp


func _init() -> void:
	id = &"surge"
	display_name = "STELLAR SURGE"
	tagline = "triple score"
	glyph = "×3"
	color = Color(2.6, 2.1, 0.6)
	duration = 7.0


func score_factor() -> int:
	return 3
