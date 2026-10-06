class_name UiKit
extends RefCounted

## Small factory for the code-built menu and lobby screens, so both share
## one look (pixel font, sizes, pitch-green background).

const PIXEL_FONT := preload("res://assets/field/font/plumppixel.ttf")
const BACKGROUND := Color(0.08, 0.22, 0.11)


## Full-screen background plus a centred column; returns the column.
static func screen(owner: Control, width: float) -> VBoxContainer:
	owner.set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	return column


static func label(text: String, font_size: int, pixel: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	if pixel:
		result.add_theme_font_override("font", PIXEL_FONT)
	return result


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 40)
	result.add_theme_font_size_override("font_size", 18)
	result.pressed.connect(on_pressed)
	return result


static func line_edit(placeholder: String, max_length: int) -> LineEdit:
	var result := LineEdit.new()
	result.placeholder_text = placeholder
	result.max_length = max_length
	result.custom_minimum_size = Vector2(0, 40)
	result.add_theme_font_size_override("font_size", 18)
	return result
