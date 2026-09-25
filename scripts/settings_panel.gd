class_name SettingsPanel
extends CenterContainer
## Settings overlay: master / music / effects volume sliders and a music
## on-off toggle. Works with keyboard (up/down to pick, left/right to adjust,
## Enter on BACK, Esc to close) and mouse. Changes apply live and are saved on close.

const ROWS := [
	[&"Master", "MASTER VOLUME"],
	[&"Music", "MUSIC VOLUME"],
	[&"SFX", "SOUND EFFECTS"],
]
const ACCENT := Color(0.35, 1.1, 1.25)

var sfx: Sfx

var _hud: Hud
var _sliders: Dictionary[StringName, HSlider] = {}
var _values: Dictionary[StringName, Label] = {}
var _names: Array[Label] = []
var _focusables: Array[Control] = []
var _music_toggle: Button
var _back: Button
var _last_preview_ms := 0


func build(hud: Hud) -> void:
	_hud = hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var panel := PanelContainer.new()
	var style := hud._style(Color(0.4, 0.8, 1.0, 0.6), 0.9)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := hud._label("SETTINGS", 40, ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(hud._spacer(6))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)

	for row in ROWS:
		var bus: StringName = row[0]
		var name_label := hud._label(row[1], 13, Config.TEXT, true)
		grid.add_child(name_label)
		_names.append(name_label)
		var slider := _slider()
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		grid.add_child(slider)
		_sliders[bus] = slider
		_focusables.append(slider)
		var value := hud._label("", 13, Config.TEXT_DIM)
		value.custom_minimum_size.x = 52
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		_values[bus] = value

	var music_label := hud._label("MUSIC", 13, Config.TEXT, true)
	grid.add_child(music_label)
	_names.append(music_label)
	_music_toggle = _button("")
	_music_toggle.toggle_mode = true
	_music_toggle.toggled.connect(_on_music_toggled)
	grid.add_child(_music_toggle)
	_focusables.append(_music_toggle)
	grid.add_child(Control.new())

	v.add_child(hud._spacer(8))
	_back = _button("BACK")
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(close)
	v.add_child(_back)
	_focusables.append(_back)

	var hint := hud._label("UP / DOWN  select     LEFT / RIGHT  adjust     ESC  close", 10, Config.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	v.add_child(hud._spacer(4))
	var credit := hud._label(Config.CREDIT_LINE, 10, Color(Config.TEXT_DIM, 0.8))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(credit)

	# Explicit vertical focus chain (the grid's geometry would otherwise let
	# up/down skip into the value labels' column).
	for i in _focusables.size():
		var c := _focusables[i]
		c.focus_neighbor_top = c.get_path_to(_focusables[posmod(i - 1, _focusables.size())])
		c.focus_neighbor_bottom = c.get_path_to(_focusables[(i + 1) % _focusables.size()])


func open() -> void:
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(roundf(sfx.get_volume(bus) * 100.0))
		_update_value_label(bus)
	_music_toggle.set_pressed_no_signal(sfx.music_enabled)
	_update_music_label()
	visible = true
	_sliders[&"Master"].grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_viewport().gui_release_focus()
	sfx.save_settings()
	sfx.play(&"blip")


func _process(_delta: float) -> void:
	if not visible:
		return
	# Highlight the label of the focused row.
	for i in _names.size():
		var focused := _focusables[i].has_focus()
		_names[i].add_theme_color_override("font_color", ACCENT if focused else Config.TEXT)
	# Keep the toggle in sync with the M hotkey.
	if _music_toggle.button_pressed != sfx.music_enabled:
		_music_toggle.set_pressed_no_signal(sfx.music_enabled)
		_update_music_label()


func _on_volume_changed(value: float, bus: StringName) -> void:
	sfx.set_volume(bus, value / 100.0)
	_update_value_label(bus)
	# Audible preview of the new level (throttled while dragging).
	if bus != &"Music" and Time.get_ticks_msec() - _last_preview_ms > 120:
		_last_preview_ms = Time.get_ticks_msec()
		sfx.play(&"eat", 1.0, true)


func _on_music_toggled(on: bool) -> void:
	if on != sfx.music_enabled:
		sfx.toggle_music()
	_update_music_label()


func _update_value_label(bus: StringName) -> void:
	_values[bus].text = "%d%%" % roundi(_sliders[bus].value)


func _update_music_label() -> void:
	_music_toggle.text = "ON" if sfx.music_enabled else "OFF"


func _slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate()
	fill.bg_color = Color(0.3, 0.95, 1.05)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(0.4, 1.0, 1.1, 0.8)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(4)
	focus.set_expand_margin_all(4)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_stylebox_override("focus", focus)
	var knob := _knob()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 34)
	b.add_theme_font_override("font", _hud._bold)
	b.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.9, 1.0, 0.22 if state in ["pressed", "hover_pressed"] else 0.08)
		sb.border_color = Color(0.4, 1.0, 1.1, 0.9 if state == "focus" else 0.35)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		if state == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Config.TEXT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	return b


static func _knob() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1), Color(0.75, 1, 1), Color(0.75, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 16
	tex.height = 16
	return tex
