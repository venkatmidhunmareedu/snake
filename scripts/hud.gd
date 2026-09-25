class_name Hud
extends Control
## Side panel (score, combo, active power-ups, field guide), the menu / pause /
## game-over overlays, pickup banners and the screen flash. Built in code and
## refreshed from the Game state every frame.

var game: Game

var _font: Font = preload("res://assets/fonts/Orbitron.ttf")
var _bold: FontVariation

var _score: Label
var _best: Label
var _combo: Label
var _combo_bar: ProgressBar
var _stats: Label
var _active_box: VBoxContainer
var _none_label: Label
var _rows: Dictionary[StringName, ProgressBar] = {}
var _shown_score := 0.0

var _menu: Control
var _menu_best: Label
var _launch_hint: Label
var _pause: Control
var _over: Control
var _over_score: Label
var _over_record: Label

var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _flash: ColorRect


func _ready() -> void:
	position = Vector2.ZERO
	size = Config.VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}

	_build_panel()
	_build_overlays()
	_build_banner()

	_flash = ColorRect.new()
	_flash.size = Config.VIEW_SIZE
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _process(delta: float) -> void:
	_shown_score = move_toward(_shown_score, game.score, maxf(40.0, absf(game.score - _shown_score) * 8.0) * delta)
	_score.text = "%06d" % roundi(_shown_score)
	_best.text = "BEST  %06d" % game.high_score
	_combo.text = "COMBO ×%d" % game.combo if game.combo >= 2 else "COMBO  —"
	_combo_bar.value = game.combo_timer / Config.COMBO_WINDOW * 100.0 if game.combo >= 1 else 0.0
	_stats.text = "LENGTH %d    SPEED %.1f×" % [game.snake.body.size(), game.speed_multiplier()]
	_sync_active()

	_menu.visible = game.ai_mode
	_pause.visible = game.state == Game.State.PAUSED
	_over.visible = not game.ai_mode and game.state == Game.State.GAME_OVER and game.state_time > 0.7
	_menu_best.text = "BEST  %d" % game.high_score
	_launch_hint.modulate.a = 0.4 + 0.6 * absf(sin(game.time * 2.4))
	_over_score.text = "SCORE  %d" % game.score
	_over_record.visible = game.new_record
	_over_record.modulate.a = 0.5 + 0.5 * absf(sin(game.time * 5.0))


func banner(title: String, subtitle: String, color: Color) -> void:
	if game.ai_mode:
		return
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", _soft(color) * 1.2)
	_banner_sub.text = subtitle
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1.35, 1.35)
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.12)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.4).set_delay(1.1)


func flash(color: Color, strength: float) -> void:
	_flash.color = Color(color, strength)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.45)


# --- Construction --------------------------------------------------------------

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Config.PANEL_RECT.position
	panel.size = Config.PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.3, 0.7, 1.0, 0.55), 0.7))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	v.add_child(_label("COSMIC SERPENT", 21, Color(0.35, 1.1, 1.2), true))
	v.add_child(_label("deep space · sector 7", 11, Config.TEXT_DIM))
	v.add_child(_divider())
	v.add_child(_label("SCORE", 11, Config.TEXT_DIM))
	_score = _label("000000", 42, Config.TEXT, true)
	v.add_child(_score)
	_best = _label("", 13, Config.TEXT_DIM)
	v.add_child(_best)
	v.add_child(_spacer(6))
	_combo = _label("", 18, Color(1.0, 0.45, 0.95), true)
	v.add_child(_combo)
	_combo_bar = _bar(Config.BONUS_FOOD)
	v.add_child(_combo_bar)
	_stats = _label("", 12, Config.TEXT_DIM)
	v.add_child(_stats)
	v.add_child(_divider())

	v.add_child(_label("ACTIVE POWER-UPS", 11, Config.TEXT_DIM))
	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 4)
	v.add_child(_active_box)
	_none_label = _label("none — hunt the planets", 12, Color(Config.TEXT_DIM, 0.6))
	_active_box.add_child(_none_label)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	v.add_child(_divider())
	v.add_child(_label("FIELD GUIDE", 11, Config.TEXT_DIM))
	# Compact two-column grid; the tagline shows in the pickup banner.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	for p in game.powerups.catalog:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := _label(p.glyph, 13, _soft(p.color) * 1.25, true)
		glyph.custom_minimum_size.x = 22
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(glyph)
		row.add_child(_label(p.display_name, 10, _soft(p.color)))
		grid.add_child(row)
	v.add_child(grid)
	v.add_child(_divider())
	v.add_child(_label("ARROWS / WASD  steer   ESC  pause   M  music", 10, Config.TEXT_DIM))


func _build_overlays() -> void:
	var area := Control.new()
	area.position = Config.BOARD_ORIGIN
	area.size = Config.BOARD_SIZE
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)

	_launch_hint = _label("PRESS ENTER TO LAUNCH", 20, Config.TEXT, true)
	_menu_best = _label("", 13, Config.TEXT_DIM)
	_menu = _overlay(area, [
		_label("COSMIC", 66, Color(0.35, 1.15, 1.25), true),
		_label("SERPENT", 66, Color(1.0, 0.4, 1.2), true),
		_label("navigate the void · devour the stars", 12, Config.TEXT_DIM),
		_spacer(22),
		_launch_hint,
		_spacer(4),
		_menu_best,
		_label("ARROWS / WASD  steer   ESC  pause   M  music", 11, Config.TEXT_DIM),
	], 0.5)

	_pause = _overlay(area, [
		_label("PAUSED", 54, Color(0.35, 1.1, 1.25), true),
		_label("ESC or ENTER to resume", 12, Config.TEXT_DIM),
	], 0.75)

	_over_score = _label("", 26, Config.TEXT, true)
	_over_record = _label("— NEW RECORD —", 15, Color(1.2, 1.05, 0.5), true)
	_over = _overlay(area, [
		_label("SIGNAL LOST", 50, Color(1.25, 0.3, 0.45), true),
		_spacer(8),
		_over_score,
		_over_record,
		_spacer(14),
		_label("ENTER  relaunch     ESC  menu", 12, Config.TEXT_DIM),
	], 0.75)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.position = Config.BOARD_ORIGIN + Vector2(0, 120)
	_banner.size = Vector2(Config.BOARD_SIZE.x, 90)
	_banner.pivot_offset = _banner.size / 2.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_banner_title = _label("", 38, Config.ACCENT, true)
	_banner_sub = _label("", 13, Config.TEXT)
	for l in [_banner_title, _banner_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(l)
	add_child(_banner)


func _overlay(parent: Control, children: Array, bg_alpha: float) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	var panel := PanelContainer.new()
	var style := _style(Color(0.4, 0.8, 1.0, 0.5), bg_alpha)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	for c: Control in children:
		if c is Label:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(c)
	return center


func _sync_active() -> void:
	var active := game.powerups.active
	for id in _rows.keys():
		if not active.has(id):
			_rows[id].get_parent().queue_free()
			_rows.erase(id)
	for id in active:
		var p := active[id]
		if not _rows.has(id):
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var title := p.display_name + ("  ·  ARMED" if is_inf(p.duration) else "")
			row.add_child(_label(title, 12, _soft(p.color), true))
			var bar := _bar(_soft(p.color) * 1.1)
			row.add_child(bar)
			_active_box.add_child(row)
			_rows[id] = bar
		_rows[id].value = 100.0 if is_inf(p.duration) else p.remaining / p.duration * 100.0
	_none_label.visible = _rows.is_empty()


# --- Widgets -------------------------------------------------------------------

func _label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	return l


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100.0
	b.custom_minimum_size = Vector2(0, 5)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.07)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _divider() -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color = Color(0.4, 0.6, 1.0, 0.22)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _style(border: Color, bg_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.08, bg_alpha)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(border.r, border.g, border.b, 0.15)
	sb.shadow_size = 18
	return sb


## Tones an HDR colour down to something readable as text.
static func _soft(c: Color) -> Color:
	var m := maxf(c.r, maxf(c.g, c.b))
	var n := Color(c.r / m, c.g / m, c.b / m) if m > 1.0 else c
	return n.lerp(Color.WHITE, 0.3)
