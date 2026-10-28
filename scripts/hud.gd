extends Control

## Safe-area aware HUD showing cash and income per second.

@onready var safe_margin: MarginContainer = $SafeMargin
@onready var cash_label: Label = $SafeMargin/HBoxContainer/CashLabel
@onready var income_label: Label = $SafeMargin/HBoxContainer/IncomeLabel

var _income_timer: Timer


func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_income_timer = Timer.new()
	_income_timer.wait_time = 0.5
	_income_timer.autostart = true
	_income_timer.timeout.connect(_refresh)
	add_child(_income_timer)
	_refresh()


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win_size := get_viewport().get_visible_rect().size
	safe_margin.add_theme_constant_override("margin_left", int(safe.position.x))
	safe_margin.add_theme_constant_override("margin_top", int(safe.position.y))
	safe_margin.add_theme_constant_override("margin_right", int(win_size.x) - int(safe.end.x))
	safe_margin.add_theme_constant_override("margin_bottom", int(win_size.y) - int(safe.end.y))


func _refresh() -> void:
	cash_label.text = "Cash: " + Economy.format_number(GameState.cash)
	var income := GameState.income_per_second_total() * Economy.income_multiplier
	income_label.text = "Income/s: " + Economy.format_number(income)