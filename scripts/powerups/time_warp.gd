extends PowerUp


func _init() -> void:
	id = &"timewarp"
	display_name = "TIME WARP"
	tagline = "slow motion"
	glyph = "T"
	color = Color(0.4, 2.3, 1.1)
	duration = 5.0


func tick_factor() -> float:
	return 1.7


func warp_factor() -> float:
	return 0.2
