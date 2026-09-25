extends PowerUp


func _init() -> void:
	id = &"stasis"
	display_name = "STASIS FIELD"
	tagline = "combo timer frozen"
	glyph = "C"
	color = Color(1.6, 2.0, 2.6)
	duration = 8.0


func apply(game: Game) -> void:
	game.combo_timer = Config.COMBO_WINDOW
