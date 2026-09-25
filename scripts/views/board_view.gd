class_name BoardView
extends Node2D
## Neon frame around the play field. Pulses with the combo and turns red when
## the head is about to hit a wall.

var game: Game


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Config.board_rect().grow(4)
	var base := Config.ACCENT
	if game.state == Game.State.PLAYING and _near_wall():
		base = base.lerp(Config.DANGER, 0.5 + 0.5 * sin(game.time * 18.0))
	var pulse := 0.5 + 0.12 * sin(game.time * 2.0) + game.combo * 0.06
	draw_rect(rect.grow(6), Color(base, 0.05), false, 10.0)
	draw_rect(rect, Color(base * 0.35, 0.8), false, 2.0)

	# Bright corner brackets.
	var arm := 34.0
	var col := Color(base * pulse, 1.0)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), col, 3.0, true)
		draw_line(corner, corner + Vector2(0, arm * sy), col, 3.0, true)


func _near_wall() -> bool:
	var next := game.snake.next_head()
	return not Config.in_bounds(next)
