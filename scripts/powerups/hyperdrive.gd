extends PowerUp


func _init() -> void:
	id = &"hyperdrive"
	display_name = "HYPERDRIVE"
	tagline = "speed up · double score"
	glyph = "H"
	color = Color(2.2, 1.2, 0.3)
	duration = 6.0


func tick_factor() -> float:
	return 0.6


func score_factor() -> int:
	return 2


func warp_factor() -> float:
	return 14.0
