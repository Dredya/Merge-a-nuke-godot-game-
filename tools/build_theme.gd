extends SceneTree

## Rebuilds resources/ui_theme.tres from code so the shared theme stays readable
## and every property is valid Godot serialisation.
## Run: godot --headless --path . --script tools/build_theme.gd

const OUT_PATH := "res://resources/ui_theme.tres"
const LILITA := "res://assets/fonts/LilitaOne-Regular.ttf"
const NUNITO := "res://assets/fonts/NunitoSans-Variable.ttf"

const C_NAVY := Color("#141C38")
const C_NAVY_DEEP := Color("#0B1020")
const C_NAVY_LIGHT := Color("#1B2547")
const C_TEXT := Color("#EAF0FF")
const C_MUTED := Color("#A9B6E0")
const C_GOLD := Color("#FFC83D")
const C_LIME := Color("#B6F23C")
const C_GREEN := Color("#3DDC5A")
const C_GREEN_EDGE := Color("#25963C")
const C_ORANGE := Color("#FF6A3D")
const C_ORANGE_EDGE := Color("#B83A17")
const C_BLUE := Color("#3A4673")
const C_BLUE_EDGE := Color("#242C4A")
const C_BLUE_BRIGHT := Color("#3A7BFF")
const C_DANGER := Color("#FF4D5E")
const C_DANGER_EDGE := Color("#AA1D2E")


func _init() -> void:
	var lilita := load(LILITA) as FontFile
	var nunito := load(NUNITO) as FontFile
	if lilita == null or nunito == null:
		push_error("Theme fonts missing")
		quit(1)
		return
	var body := FontVariation.new()
	body.base_font = nunito
	body.variation_opentype = {&"wght": 700.0}
	body.variation_embolden = 0.35

	var theme := Theme.new()
	theme.default_font = body
	theme.default_font_size = 28
	_apply_base_label(theme, body)
	_apply_panels(theme)
	_apply_buttons(theme, body)
	_apply_labels(theme, lilita, body)
	_apply_inputs(theme, body)
	_apply_progress(theme)

	var err := ResourceSaver.save(theme, OUT_PATH)
	print("Theme saved: ", OUT_PATH, " err=", err)
	quit(0 if err == OK else 1)


func _apply_base_label(theme: Theme, body: Font) -> void:
	theme.set_font("font", "Label", body)
	theme.set_font_size("font_size", "Label", 28)
	theme.set_color("font_color", "Label", C_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0.04, 0.06, 0.12, 0.8))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_color("font_outline_color", "Label", C_NAVY_DEEP)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", 6)


func _apply_panels(theme: Theme) -> void:
	var base := _panel(C_NAVY, 3, C_NAVY_DEEP, 14, 18)
	theme.set_stylebox("panel", "PanelContainer", base)

	theme.set_type_variation("PanelHud", "PanelContainer")
	theme.set_stylebox("panel", "PanelHud", _panel(Color(C_NAVY.r, C_NAVY.g, C_NAVY.b, 0.92), 3, C_NAVY_DEEP, 14, 18))

	theme.set_type_variation("PanelCard", "PanelContainer")
	theme.set_stylebox("panel", "PanelCard", _panel(Color(C_NAVY_LIGHT.r, C_NAVY_LIGHT.g, C_NAVY_LIGHT.b, 0.92), 3, C_NAVY_DEEP, 14, 14))

	theme.set_type_variation("PanelPopup", "PanelContainer")
	theme.set_stylebox("panel", "PanelPopup", _panel(Color(C_NAVY.r, C_NAVY.g, C_NAVY.b, 0.96), 3, C_NAVY_DEEP, 14, 26))

	theme.set_type_variation("PanelLock", "PanelContainer")
	theme.set_stylebox("panel", "PanelLock", _panel(C_NAVY_DEEP, 3, C_BLUE_BRIGHT, 14, 12))

	theme.set_type_variation("PanelNav", "PanelContainer")
	var nav := _panel(Color(C_NAVY_DEEP.r, C_NAVY_DEEP.g, C_NAVY_DEEP.b, 0.98), 0, Color.TRANSPARENT, 0, 4)
	nav.border_width_top = 2
	nav.border_color = C_NAVY_LIGHT
	theme.set_stylebox("panel", "PanelNav", nav)

	theme.set_type_variation("PanelToast", "PanelContainer")
	theme.set_stylebox("panel", "PanelToast", _panel(Color(C_NAVY_DEEP.r, C_NAVY_DEEP.g, C_NAVY_DEEP.b, 0.94), 2, C_BLUE_BRIGHT, 12, 10))


func _apply_buttons(theme: Theme, body: Font) -> void:
	_apply_button_type(theme, "Button", body, C_GREEN, C_GREEN_EDGE)
	_apply_button_type(theme, "OptionButton", body, C_BLUE, C_BLUE_EDGE)
	_apply_button_type(theme, "CheckButton", body, C_NAVY_LIGHT, C_NAVY_DEEP)

	_button_variation(theme, "GreenButton", body, C_GREEN, C_GREEN_EDGE)
	_button_variation(theme, "OrangeButton", body, C_ORANGE, C_ORANGE_EDGE)
	_button_variation(theme, "BlueButton", body, C_BLUE, C_BLUE_EDGE)
	_button_variation(theme, "DangerButton", body, C_DANGER, C_DANGER_EDGE)
	_gold_button(theme, body)
	_nav_button(theme, body)
	_small_button(theme, body)


func _apply_button_type(theme: Theme, type_name: String, body: Font, color: Color, edge: Color) -> void:
	theme.set_font("font", type_name, body)
	theme.set_font_size("font_size", type_name, 32)
	theme.set_constant("outline_size", type_name, 0)
	theme.set_color("font_color", type_name, Color.WHITE)
	theme.set_color("font_hover_color", type_name, Color.WHITE)
	theme.set_color("font_pressed_color", type_name, Color.WHITE)
	theme.set_color("font_focus_color", type_name, Color.WHITE)
	theme.set_color("font_disabled_color", type_name, Color("#7C89B8"))
	theme.set_color("font_hover_pressed_color", type_name, Color.WHITE)
	theme.set_color("font_outline_color", type_name, C_NAVY_DEEP)
	theme.set_color("font_shadow_color", type_name, Color(0.02, 0.03, 0.07, 0.9))
	theme.set_constant("shadow_offset_x", type_name, 2)
	theme.set_constant("shadow_offset_y", type_name, 3)
	theme.set_stylebox("normal", type_name, _button_style(color, edge, 6, 14, 24))
	theme.set_stylebox("hover", type_name, _button_style(color.lightened(0.06), edge, 6, 14, 24))
	theme.set_stylebox("pressed", type_name, _button_style(color.darkened(0.10), edge.darkened(0.15), 2, 18, 24))
	theme.set_stylebox("hover_pressed", type_name, _button_style(color.darkened(0.06), edge.darkened(0.1), 2, 18, 24))
	theme.set_stylebox("disabled", type_name, _button_style(Color("#2A3355"), Color("#1A213D"), 4, 16, 24, Color("#7C89B8")))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())


func _button_variation(theme: Theme, variant: String, body: Font, color: Color, edge: Color) -> void:
	theme.set_type_variation(variant, "Button")
	theme.set_font("font", variant, body)
	theme.set_font_size("font_size", variant, 32)
	theme.set_color("font_color", variant, Color.WHITE)
	theme.set_color("font_hover_color", variant, Color.WHITE)
	theme.set_color("font_pressed_color", variant, Color.WHITE)
	theme.set_color("font_focus_color", variant, Color.WHITE)
	theme.set_color("font_disabled_color", variant, Color("#7C89B8"))
	theme.set_color("font_outline_color", variant, C_NAVY_DEEP)
	theme.set_color("font_shadow_color", variant, Color(0.02, 0.03, 0.07, 0.9))
	theme.set_constant("outline_size", variant, 0)
	theme.set_constant("shadow_offset_x", variant, 2)
	theme.set_constant("shadow_offset_y", variant, 3)
	theme.set_stylebox("normal", variant, _button_style(color, edge, 6, 14, 24))
	theme.set_stylebox("hover", variant, _button_style(color.lightened(0.06), edge, 6, 14, 24))
	theme.set_stylebox("pressed", variant, _button_style(color.darkened(0.10), edge.darkened(0.15), 2, 18, 24))
	theme.set_stylebox("hover_pressed", variant, _button_style(color.darkened(0.06), edge.darkened(0.1), 2, 18, 24))
	theme.set_stylebox("disabled", variant, _button_style(Color("#2A3355"), Color("#1A213D"), 4, 16, 24, Color("#7C89B8")))
	theme.set_stylebox("focus", variant, StyleBoxEmpty.new())


func _gold_button(theme: Theme, body: Font) -> void:
	theme.set_type_variation("GoldButton", "Button")
	theme.set_font("font", "GoldButton", body)
	theme.set_font_size("font_size", "GoldButton", 30)
	theme.set_color("font_color", "GoldButton", Color("#3A2A00"))
	theme.set_color("font_hover_color", "GoldButton", Color("#3A2A00"))
	theme.set_color("font_pressed_color", "GoldButton", Color("#3A2A00"))
	theme.set_stylebox("normal", "GoldButton", _button_style(C_GOLD, Color("#B98210"), 6, 12, 20))
	theme.set_stylebox("hover", "GoldButton", _button_style(C_GOLD.lightened(0.06), Color("#B98210"), 6, 12, 20))
	theme.set_stylebox("pressed", "GoldButton", _button_style(C_GOLD.darkened(0.08), Color("#9A6A08"), 2, 16, 20))
	theme.set_stylebox("disabled", "GoldButton", _button_style(Color("#574E33"), Color("#3B3522"), 4, 14, 20, Color("#A9A18A")))
	theme.set_stylebox("focus", "GoldButton", StyleBoxEmpty.new())


func _nav_button(theme: Theme, body: Font) -> void:
	theme.set_type_variation("NavButton", "Button")
	theme.set_font("font", "NavButton", body)
	theme.set_font_size("font_size", "NavButton", 20)
	theme.set_color("font_color", "NavButton", C_MUTED)
	theme.set_color("font_hover_color", "NavButton", C_TEXT)
	theme.set_color("font_pressed_color", "NavButton", C_LIME)
	theme.set_color("font_focus_color", "NavButton", C_TEXT)
	theme.set_stylebox("normal", "NavButton", _flat_style(Color.TRANSPARENT, 0, 8, 4))
	theme.set_stylebox("hover", "NavButton", _flat_style(Color(C_NAVY_LIGHT.r, C_NAVY_LIGHT.g, C_NAVY_LIGHT.b, 0.65), 0, 8, 4))
	theme.set_stylebox("pressed", "NavButton", _flat_style(Color(C_NAVY.r, C_NAVY.g, C_NAVY.b, 0.9), 0, 8, 4))
	theme.set_stylebox("disabled", "NavButton", _flat_style(Color.TRANSPARENT, 0, 8, 4))
	theme.set_stylebox("focus", "NavButton", StyleBoxEmpty.new())


func _small_button(theme: Theme, body: Font) -> void:
	theme.set_type_variation("SmallButton", "Button")
	theme.set_font("font", "SmallButton", body)
	theme.set_font_size("font_size", "SmallButton", 24)
	theme.set_color("font_color", "SmallButton", Color.WHITE)
	theme.set_stylebox("normal", "SmallButton", _button_style(C_BLUE, C_BLUE_EDGE, 4, 10, 16))
	theme.set_stylebox("hover", "SmallButton", _button_style(C_BLUE.lightened(0.08), C_BLUE_EDGE, 4, 10, 16))
	theme.set_stylebox("pressed", "SmallButton", _button_style(C_BLUE.darkened(0.1), C_BLUE_EDGE, 2, 13, 16))
	theme.set_stylebox("disabled", "SmallButton", _button_style(Color("#2A3355"), Color("#1A213D"), 3, 11, 16, Color("#7C89B8")))
	theme.set_stylebox("focus", "SmallButton", StyleBoxEmpty.new())


func _apply_labels(theme: Theme, lilita: Font, body: Font) -> void:
	_label(theme, "DisplayTitle", lilita, 72, Color.WHITE, 10, true)
	_label(theme, "TitleLabel", lilita, 56, Color.WHITE, 8, true)
	_label(theme, "H2", lilita, 42, Color.WHITE, 6, false)
	_label(theme, "CashAmount", lilita, 64, C_GOLD, 10, true)
	_label(theme, "BigGold", lilita, 92, C_GOLD, 12, true)
	_label(theme, "HudCaption", body, 22, C_MUTED, 0, false)
	_label(theme, "IncomeLabel", body, 30, C_LIME, 4, false)
	_label(theme, "MutedLabel", body, 24, C_MUTED, 0, false)
	_label(theme, "GoldLabel", body, 28, C_GOLD, 0, false)
	_label(theme, "DangerLabel", body, 26, C_DANGER, 0, false)
	_label(theme, "NavLabel", body, 20, C_MUTED, 0, false)
	_label(theme, "LockedLabel", body, 20, Color("#6FA0FF"), 0, false)
	_label(theme, "TimerLabel", lilita, 34, Color("#6FA0FF"), 6, false)
	_label(theme, "WhiteLabel", body, 26, Color.WHITE, 0, false)


func _label(theme: Theme, variant: String, font: Font, size: int, color: Color, outline: int, shadow: bool) -> void:
	theme.set_type_variation(variant, "Label")
	theme.set_font("font", variant, font)
	theme.set_font_size("font_size", variant, size)
	theme.set_color("font_color", variant, color)
	theme.set_color("font_outline_color", variant, C_NAVY_DEEP)
	theme.set_constant("outline_size", variant, outline)
	if shadow:
		theme.set_color("font_shadow_color", variant, Color(0.02, 0.03, 0.07, 0.85))
		theme.set_constant("shadow_offset_x", variant, 3)
		theme.set_constant("shadow_offset_y", variant, 4)
	else:
		theme.set_color("font_shadow_color", variant, Color.TRANSPARENT)


func _apply_inputs(theme: Theme, body: Font) -> void:
	theme.set_font("font", "LineEdit", body)
	theme.set_font_size("font_size", "LineEdit", 28)
	theme.set_color("font_color", "LineEdit", C_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color("#7C89B8"))
	theme.set_stylebox("normal", "LineEdit", _panel(C_NAVY_DEEP, 3, C_BLUE_BRIGHT, 10, 14))
	theme.set_stylebox("focus", "LineEdit", _panel(C_NAVY_DEEP, 3, C_LIME, 10, 14))
	theme.set_stylebox("read_only", "LineEdit", _panel(C_NAVY_DEEP, 3, C_NAVY_LIGHT, 10, 14))
	theme.set_constant("caret_width", "LineEdit", 2)


func _apply_progress(theme: Theme) -> void:
	var bg := _panel(C_NAVY_DEEP, 2, C_NAVY_DEEP, 8, 0)
	var fill := _panel(C_LIME, 0, Color.TRANSPARENT, 8, 0)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_font_size("font_size", "ProgressBar", 18)
	theme.set_color("font_color", "ProgressBar", C_NAVY_DEEP)


# --- Style helpers ---------------------------------------------------------

func _panel(fill: Color, border: int, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border)
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	style.content_margin_left = float(margin)
	style.content_margin_right = float(margin)
	style.content_margin_top = float(margin)
	style.content_margin_bottom = float(margin)
	style.anti_aliasing = true
	return style


func _button_style(
	fill: Color,
	edge: Color,
	bottom_border: int,
	top_margin: int,
	side_margin: int,
	font_color: Color = Color.WHITE
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = bottom_border
	style.border_color = edge
	style.set_corner_radius_all(14)
	style.content_margin_left = float(side_margin)
	style.content_margin_right = float(side_margin)
	style.content_margin_top = float(top_margin)
	style.content_margin_bottom = float(top_margin + 2)
	style.anti_aliasing = true
	style.shadow_color = Color(0.02, 0.03, 0.07, 0.28)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	return style


func _flat_style(fill: Color, border: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border)
	style.border_color = Color.TRANSPARENT
	style.set_corner_radius_all(10)
	style.content_margin_left = float(margin_x)
	style.content_margin_right = float(margin_x)
	style.content_margin_top = float(margin_y)
	style.content_margin_bottom = float(margin_y)
	return style
