class_name PowerUp
extends RefCounted
## Base class for power-ups. Subclasses set their fields in _init() and override
## the hooks they need. duration: 0 = instant, INF = lasts until consumed.

var id: StringName
var display_name := ""
var tagline := ""
var glyph := ""
var color := Color.WHITE
var duration := 0.0
var remaining := 0.0


func apply(_game: Game) -> void:
	pass


func expire(_game: Game) -> void:
	pass


## Multiplier on the tick interval (<1 is faster).
func tick_factor() -> float:
	return 1.0


func score_factor() -> int:
	return 1


## Multiplier on background star drift.
func warp_factor() -> float:
	return 1.0


func is_instant() -> bool:
	return duration <= 0.0
