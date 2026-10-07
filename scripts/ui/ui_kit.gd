class_name UiKit
extends RefCounted

## Shared look for the code-built menu and lobby: the real pitch as a darkened
## backdrop, a pixel-font title, frosted cards, and buttons coloured by team.

const PIXEL_FONT := preload("res://assets/field/font/plumppixel.ttf")
## Loaded at runtime (not preloaded) so the headless server, which ships
## without this large texture, never tries to load it.
const FIELD_TEXTURE_PATH := "res://assets/field/field.png"

const BLUE := Color(0.2, 0.35, 1.0)
const RED := Color(0.95, 0.25, 0.25)
const GREEN := Color(0.18, 0.62, 0.32)
const TEXT := Color(0.96, 0.97, 0.95)
const MUTED := Color(0.78, 0.84, 0.8, 0.75)
const HIGHLIGHT := Color(1.0, 0.85, 0.3)

enum Style { PRIMARY, DANGER, SUCCESS, GHOST }


## Pitch backdrop plus a centred column; returns the column.
static func screen(owner: Control) -> VBoxContainer:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pitch := TextureRect.new()
	pitch.texture = load(FIELD_TEXTURE_PATH)
	pitch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pitch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pitch.modulate = Color(0.55, 0.6, 0.55)
	pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(pitch)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.04, 0.02, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	return column


## Frosted rounded panel; returns the column inside it. `accent` tints the
## border (team cards in the lobby).
static func card(parent: Control, width: float, accent: Color = Color(1, 1, 1, 0.14)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var style := _box(Color(0.03, 0.07, 0.05, 0.82), 14, accent, 2)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


## Big pixel-font heading with an outline and drop shadow.
static func title(text: String, font_size: int, color: Color = TEXT) -> Label:
	var result := label(text, font_size, color)
	result.add_theme_font_override("font", PIXEL_FONT)
	result.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03))
	result.add_theme_constant_override("outline_size", maxi(font_size / 6, 4))
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	result.add_theme_constant_override("shadow_offset_x", 0)
	result.add_theme_constant_override("shadow_offset_y", maxi(font_size / 12, 2))
	return result


## Small upper-case label above a field.
static func caption(text: String) -> Label:
	var result := label(text.to_upper(), 12, MUTED)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return result


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, on_pressed: Callable, style: Style = Style.PRIMARY) -> Button:
	var result := Button.new()
	result.text = text.to_upper()
	result.custom_minimum_size = Vector2(0, 46)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", PIXEL_FONT)
	result.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, TEXT)
	result.add_theme_color_override("font_disabled_color", Color(TEXT, 0.4))

	var base: Color = {
		Style.PRIMARY: BLUE, Style.DANGER: RED, Style.SUCCESS: GREEN, Style.GHOST: Color(1, 1, 1, 0.06),
	}[style]
	var border := Color(1, 1, 1, 0.28) if style == Style.GHOST else base.lightened(0.25)
	result.add_theme_stylebox_override("normal", _box(base, 10, border, 2))
	result.add_theme_stylebox_override("hover", _box(base.lightened(0.15), 10, Color(1, 1, 1, 0.6), 2))
	result.add_theme_stylebox_override("pressed", _box(base.darkened(0.2), 10, border, 2))
	result.add_theme_stylebox_override("disabled", _box(Color(base, base.a * 0.4), 10, Color(border, 0.2), 2))
	result.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, 10, Color(1, 1, 1, 0.8), 2))
	result.pressed.connect(on_pressed)
	return result


static func line_edit(placeholder: String, max_length: int) -> LineEdit:
	var result := LineEdit.new()
	result.placeholder_text = placeholder
	result.max_length = max_length
	result.custom_minimum_size = Vector2(0, 46)
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.35))
	result.add_theme_color_override("caret_color", HIGHLIGHT)
	var normal := _box(Color(0, 0, 0, 0.35), 10, Color(1, 1, 1, 0.16), 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var focus := normal.duplicate()
	focus.border_color = HIGHLIGHT
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("focus", focus)
	return result


## Thin rule with a word in the middle: ──── or ────
static func divider(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.14)
		line.custom_minimum_size = Vector2(0, 1)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		if i == 0:
			var word := label(text, 12, MUTED)
			word.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(word)
	return row


## Muted one-line hint pinned to the bottom of the screen.
static func footer(owner: Control, text: String) -> Label:
	var hint := label(text, 14, MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44
	hint.offset_bottom = -20
	owner.add_child(hint)
	return hint


static func _box(color: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_content_margin_all(8)
	box.anti_aliasing = true
	return box
