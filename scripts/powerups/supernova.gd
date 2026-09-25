extends PowerUp

const BONUS_COUNT := 7


func _init() -> void:
	id = &"supernova"
	display_name = "SUPERNOVA"
	tagline = "a burst of bonus stars"
	glyph = "N"
	color = Color(2.6, 0.7, 1.4)
	duration = 0.0


func apply(game: Game) -> void:
	game.spawn_bonus_burst(BONUS_COUNT)
