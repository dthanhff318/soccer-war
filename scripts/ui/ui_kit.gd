class_name UiKit
extends RefCounted

## Shared 8-bit look for the code-built menu and lobby: pixel-font text,
## chunky outlined boxes with chamfered corners and a thick bottom edge (so
## buttons read as raised blocks), and buttons coloured by team.

const PIXEL_FONT := preload("res://assets/field/font/plumppixel.ttf")
## Loaded at runtime (not preloaded) so the headless server, which ships
## without this large texture, never tries to load it.
const FIELD_TEXTURE_PATH := "res://assets/field/field.png"

const BLUE := Color(0.2, 0.35, 1.0)
const RED := Color(0.95, 0.25, 0.25)
const GREEN := Color(0.18, 0.62, 0.32)
const ORANGE := Color(0.93, 0.5, 0.12)
## Title colour picked from the stadium stands in the menu artwork.
const GOLD := Color(1.0, 0.8, 0.25)
const TEXT := Color(0.96, 0.97, 0.95)
const MUTED := Color(0.78, 0.84, 0.8, 0.75)
const HIGHLIGHT := Color(1.0, 0.85, 0.3)

## Pixel box geometry: outline width, extra bottom edge ("depth"), and the
## size of the 45° corner cut.
const EDGE := 3
const DEPTH := 4
const CHAMFER := 4
## Near-black outline used by every pixel box.
const OUTLINE := Color(0.04, 0.04, 0.07)

## How far and how slowly the menu artwork drifts.
const DRIFT_PIXELS := 40.0
const DRIFT_SECONDS := 14.0

enum Style { PRIMARY, DANGER, SUCCESS, GHOST, ACCENT }


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


## Full-screen artwork that drifts slowly from side to side, darkened at the
## top (behind the title) and bottom (behind the buttons) for readability.
static func artwork_backdrop(owner: Control, texture: Texture2D) -> void:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.clip_contents = true
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Wider than the screen so it has room to drift without showing an edge.
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	art.offset_left = -DRIFT_PIXELS
	art.offset_right = DRIFT_PIXELS
	owner.add_child(art)
	var drift := art.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(art, "position:x", 0.0, DRIFT_SECONDS).from(-2.0 * DRIFT_PIXELS)
	drift.tween_property(art, "position:x", -2.0 * DRIFT_PIXELS, DRIFT_SECONDS)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.02, 0.02, 0.05, 0.8), Color(0.02, 0.02, 0.05, 0.15),
		Color(0.01, 0.04, 0.02, 0.2), Color(0.01, 0.04, 0.02, 0.85),
	])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(shade)


## Dark pixel panel; returns the column inside it. `accent` colours the
## outline (team cards in the lobby).
static func card(parent: Control, width: float, accent: Color = OUTLINE) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var style := _pixel_box(Color(0.03, 0.07, 0.05, 0.9), accent if accent.a > 0.5 else OUTLINE, DEPTH + 2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	# Clicks on the panel stay on it (a modal's backdrop closes on outside clicks).
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
		Style.PRIMARY: BLUE, Style.DANGER: RED, Style.SUCCESS: GREEN,
		Style.GHOST: Color(0.05, 0.07, 0.1, 0.78), Style.ACCENT: ORANGE,
	}[style]
	result.add_theme_stylebox_override("normal", _pixel_box(base, OUTLINE, DEPTH))
	result.add_theme_stylebox_override("hover", _pixel_box(base.lightened(0.18), OUTLINE, DEPTH))
	# Pressed: the thick bottom edge goes away and the label drops into it.
	var pressed := _pixel_box(base.darkened(0.15), OUTLINE, 0)
	pressed.content_margin_top += DEPTH
	result.add_theme_stylebox_override("pressed", pressed)
	result.add_theme_stylebox_override("disabled", _pixel_box(Color(base, base.a * 0.45), Color(OUTLINE, 0.6), DEPTH))
	result.add_theme_stylebox_override("focus", _pixel_box(Color.TRANSPARENT, HIGHLIGHT, 0))
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
	var normal := _pixel_box(Color(0, 0, 0, 0.55), OUTLINE, 0)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var focus: StyleBoxFlat = normal.duplicate()
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


## Selectable row in a list: a colour chip and a name. Toggle buttons in one
## ButtonGroup, so the picked row stays highlighted.
static func list_entry(text: String, chip: Color, group: ButtonGroup, on_pressed: Callable) -> Button:
	var entry := button(text, on_pressed, Style.GHOST)
	entry.toggle_mode = true
	entry.button_group = group
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.custom_minimum_size.y = 40
	entry.add_theme_font_size_override("font_size", 18)
	entry.icon = color_chip(chip, 14)
	entry.add_theme_constant_override("h_separation", 12)
	var picked := _pixel_box(Color(0.12, 0.16, 0.24, 0.95), HIGHLIGHT, 0)
	entry.add_theme_stylebox_override("pressed", picked)
	entry.add_theme_stylebox_override("hover_pressed", picked)
	return entry


## Small square of solid colour with a dark pixel outline.
static func color_chip(color: Color, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(OUTLINE)
	image.fill_rect(Rect2i(2, 2, size - 4, size - 4), color)
	return ImageTexture.create_from_image(image)


## Pixel stat bar for a 1–99 value.
static func stat_bar(value: int, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 99
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _pixel_box(Color(0, 0, 0, 0.55), OUTLINE, 0))
	var filled := _pixel_box(fill, OUTLINE, 0)
	filled.corner_detail = 1
	bar.add_theme_stylebox_override("fill", filled)
	return bar


## A keyboard key drawn as a small light pixel block, e.g. [SPACE].
static func key_cap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var style := _pixel_box(Color(0.92, 0.92, 0.86), OUTLINE, DEPTH)
	# Margins include the outline, so the thick bottom edge never covers the text.
	style.content_margin_left = EDGE + 8
	style.content_margin_right = EDGE + 8
	style.content_margin_top = EDGE + 4
	style.content_margin_bottom = EDGE + DEPTH + 3
	cap.add_theme_stylebox_override("panel", style)
	var letters := Label.new()
	letters.text = text
	letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letters.add_theme_font_override("font", PIXEL_FONT)
	letters.add_theme_font_size_override("font_size", 16)
	letters.add_theme_color_override("font_color", OUTLINE)
	cap.add_child(letters)
	return cap


## Chunky 8-bit box: hard outline, 45° corner cuts, no smoothing, and a
## thicker bottom edge (`depth`) so it reads as a raised block.
static func _pixel_box(fill: Color, outline: Color, depth: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = outline
	box.set_border_width_all(EDGE)
	box.border_width_bottom = EDGE + depth
	box.set_corner_radius_all(CHAMFER)
	box.corner_detail = 1
	box.anti_aliasing = false
	box.set_content_margin_all(8)
	return box
