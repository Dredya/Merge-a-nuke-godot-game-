class_name NavIcon
extends Control

## Tiny code-drawn navigation icon (no image assets).

@export_enum("home", "shop", "raid", "upgrades", "settings") var kind: String = "home"
@export var icon_color: Color = Color("#A9B6E0"):
	set(value):
		icon_color = value
		queue_redraw()
@export var plate_color: Color = Color("#0B1020")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44.0, 44.0)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var extent := minf(size.x, size.y)
	if extent <= 1.0:
		return
	var c := size * 0.5
	var s := extent
	var col := icon_color
	var w := maxf(3.0, s * 0.095)
	match kind:
		"home":
			var roof := PackedVector2Array([
				c + Vector2(0.0, -0.44 * s),
				c + Vector2(0.46 * s, 0.03 * s),
				c + Vector2(-0.46 * s, 0.03 * s),
			])
			draw_colored_polygon(roof, col)
			draw_rect(Rect2(c + Vector2(-0.31 * s, 0.02 * s), Vector2(0.62 * s, 0.40 * s)), col, true)
			draw_rect(Rect2(c + Vector2(-0.09 * s, 0.18 * s), Vector2(0.18 * s, 0.24 * s)), plate_color, true)
		"shop":
			# Shopping cart: handle, basket, two wheels.
			draw_line(c + Vector2(-0.46 * s, -0.34 * s), c + Vector2(-0.30 * s, -0.34 * s), col, w, true)
			draw_line(c + Vector2(-0.30 * s, -0.34 * s), c + Vector2(-0.18 * s, 0.04 * s), col, w, true)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.24 * s, -0.22 * s),
				c + Vector2(0.42 * s, -0.22 * s),
				c + Vector2(0.30 * s, 0.14 * s),
				c + Vector2(-0.10 * s, 0.14 * s),
			]), col)
			draw_circle(c + Vector2(-0.04 * s, 0.34 * s), 0.065 * s, col)
			draw_circle(c + Vector2(0.28 * s, 0.34 * s), 0.065 * s, col)
		"raid":
			var rocket := PackedVector2Array([
				c + Vector2(0.0, -0.46 * s),
				c + Vector2(0.19 * s, -0.10 * s),
				c + Vector2(0.19 * s, 0.28 * s),
				c + Vector2(-0.19 * s, 0.28 * s),
				c + Vector2(-0.19 * s, -0.10 * s),
			])
			draw_colored_polygon(rocket, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-0.19 * s, 0.10 * s),
				c + Vector2(-0.38 * s, 0.36 * s),
				c + Vector2(-0.19 * s, 0.30 * s),
			]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.19 * s, 0.10 * s),
				c + Vector2(0.38 * s, 0.36 * s),
				c + Vector2(0.19 * s, 0.30 * s),
			]), col)
			draw_circle(c + Vector2(0.0, -0.06 * s), 0.075 * s, plate_color)
		"upgrades":
			draw_rect(Rect2(c + Vector2(-0.36 * s, 0.10 * s), Vector2(0.16 * s, 0.30 * s)), col, true)
			draw_rect(Rect2(c + Vector2(-0.08 * s, -0.08 * s), Vector2(0.16 * s, 0.48 * s)), col, true)
			draw_rect(Rect2(c + Vector2(0.20 * s, -0.28 * s), Vector2(0.16 * s, 0.68 * s)), col, true)
		"settings":
			for i in range(8):
				var angle := float(i) * TAU / 8.0
				draw_circle(c + Vector2(cos(angle), sin(angle)) * 0.34 * s, 0.075 * s, col)
			draw_arc(c, 0.26 * s, 0.0, TAU, 24, col, w, true)
			draw_circle(c, 0.095 * s, col)
