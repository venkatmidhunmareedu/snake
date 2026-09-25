class_name Config
## Shared constants: board geometry, pacing, and the colour palette.
## Colours with channels above 1.0 are HDR and bloom through the WorldEnvironment glow.

const GRID := Vector2i(24, 24)
const CELL := 32
const BOARD_ORIGIN := Vector2(56, 56)
const BOARD_SIZE := Vector2(GRID * CELL)
const VIEW_SIZE := Vector2(1280, 880)
const PANEL_RECT := Rect2(880, 56, 344, 768)

const START_CELL := Vector2i(6, 12)
const START_LENGTH := 4

const BASE_TICK := 0.14
const MIN_TICK := 0.065
const TICK_STEP := 0.0035 ## interval shaved off per food eaten

const FOOD_POINTS := 10
const COMBO_WINDOW := 2.4
const COMBO_MAX := 8

const POWERUP_FIRST_SPAWN := 5.0
const POWERUP_SPAWN_MIN := 8.0
const POWERUP_SPAWN_MAX := 15.0
const POWERUP_LIFETIME := 8.0

const SAVE_PATH := "user://cosmic_serpent.cfg"

# Palette
const SNAKE_HEAD := Color(0.25, 1.05, 1.1)
const SNAKE_TAIL := Color(0.6, 0.2, 1.15)
const SNAKE_CORE := Color(0.8, 2.6, 2.8)
const FOOD := Color(2.4, 2.1, 0.9)
const BONUS_FOOD := Color(2.4, 0.9, 2.2)
const ACCENT := Color(0.35, 1.9, 2.2)
const DANGER := Color(2.4, 0.5, 0.7)
const TEXT := Color(0.85, 0.92, 1.0)
const TEXT_DIM := Color(0.55, 0.66, 0.88)


static func cell_center(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID.x and cell.y < GRID.y


static func board_rect() -> Rect2:
	return Rect2(BOARD_ORIGIN, BOARD_SIZE)


## Soft radial dot used as the texture for every particle system.
static func soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex
