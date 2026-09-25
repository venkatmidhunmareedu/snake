extends PowerUp


func _init() -> void:
	id = &"molt"
	display_name = "MOLT"
	tagline = "shed your tail for points"
	glyph = "M"
	color = Color(1.4, 2.4, 0.3)
	duration = 0.0


func can_spawn(game: Game) -> bool:
	return game.snake.body.size() >= Config.START_LENGTH + 6


func apply(game: Game) -> void:
	game.molt()
