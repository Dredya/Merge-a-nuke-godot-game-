extends Control

## Raid targets list and raid sequence presentation.

@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var result_popup: PanelContainer = $ResultPopup
@onready var result_label: Label = $ResultPopup/VBoxContainer/ResultLabel
@onready var ok_button: Button = $ResultPopup/VBoxContainer/OkButton

# Raid animation state
var _raiding: bool = false
var _raid_progress: float = 0.0
var _raid_nuke: ColorRect = null
var _raid_trail: Line2D = null
var _raid_trail_points: Array[Vector2] = []
var _raid_start: Vector2 = Vector2.ZERO
var _raid_ctrl: Vector2 = Vector2.ZERO
var _raid_end: Vector2 = Vector2.ZERO
var _pending_stolen: float = 0.0
var _pending_target: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	ok_button.pressed.connect(func(): result_popup.visible = false)
	RaidService.targets_refreshed.connect(_refresh_list)
	_refresh_list()


func _refresh_list() -> void:
	for child in list_container.get_children():
		child.queue_free()
	for t in RaidService.get_targets():
		if not (t is Dictionary):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)
		var name_label := Label.new()
		name_label.text = str(t.get("name", "Base"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var loot_label := Label.new()
		loot_label.text = "Loot: " + Economy.format_number(float(t.get("cash", 0.0)))
		loot_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(loot_label)
		var lock_label := Label.new()
		var locked := bool(t.get("locked", false))
		lock_label.text = "LOCKED" if locked else "Open"
		lock_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(lock_label)
		var raid_btn := Button.new()
		raid_btn.text = "Counter-Raid" if bool(t.get("is_revenge", false)) else "Raid"
		var now := Time.get_unix_time_from_system()
		var cooldown := float(t.get("cooldown_until", 0.0))
		raid_btn.disabled = locked or now < cooldown
		raid_btn.pressed.connect(_on_raid_pressed.bind(t.duplicate()))
		row.add_child(raid_btn)
		list_container.add_child(row)


func _on_raid_pressed(target: Dictionary) -> void:
	if _raiding:
		return
	var locked := bool(target.get("locked", false))
	if locked:
		return
	var now := Time.get_unix_time_from_system()
	if now < float(target.get("cooldown_until", 0.0)):
		return
	_pending_target = target
	_pending_stolen = float(target.get("cash", 0.0)) * 0.2
	if _pending_stolen < 1.0:
		_pending_stolen = 1.0
	_start_raid_animation()


func _start_raid_animation() -> void:
	_raiding = true
	_raid_progress = 0.0
	_raid_trail_points.clear()
	_raid_nuke = ColorRect.new()
	_raid_nuke.color = Color(1.0, 0.9, 0.2, 1.0)
	_raid_nuke.custom_minimum_size = Vector2(20, 20)
	_raid_nuke.size = Vector2(20, 20)
	add_child(_raid_nuke)
	_raid_trail = Line2D.new()
	_raid_trail.width = 4.0
	_raid_trail.default_color = Color(1.0, 0.6, 0.1, 0.8)
	add_child(_raid_trail)
	var w := size.x
	var h := size.y
	_raid_start = Vector2(-30.0, h * 0.5)
	_raid_ctrl = Vector2(w * 0.35, h * 0.2)
	_raid_end = Vector2(w * 0.5, h * 0.5)
	var tween := create_tween()
	tween.tween_property(self, "_raid_progress", 1.0, 0.8)
	tween.finished.connect(_on_raid_anim_finished)


func _process(delta: float) -> void:
	if not _raiding:
		return
	# bezier position
	var t := _raid_progress
	var pos := (1.0 - t) * (1.0 - t) * _raid_start + 2.0 * (1.0 - t) * t * _raid_ctrl + t * t * _raid_end
	if _raid_nuke != null:
		_raid_nuke.position = pos - Vector2(10, 10)
	_raid_trail_points.append(pos)
	if _raid_trail_points.size() > 40:
		_raid_trail_points.pop_front()
	if _raid_trail != null:
		_raid_trail.points = PackedVector2Array(_raid_trail_points)


func _on_raid_anim_finished() -> void:
	# cleanup nuke/trail
	if _raid_nuke != null:
		_raid_nuke.queue_free()
		_raid_nuke = null
	if _raid_trail != null:
		_raid_trail.queue_free()
		_raid_trail = null
	# explosion particles
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 48
	particles.lifetime = 0.6
	particles.spread = 180.0
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 10.0
	particles.color = Color(1.0, 0.5, 0.1, 1.0)
	add_child(particles)
	particles.position = _raid_end
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)
	# screen shake
	_screen_shake()
	# grant cash
	GameState.add_cash(_pending_stolen)
	# update target cooldown/cash
	var now := Time.get_unix_time_from_system()
	for t in RaidService.targets:
		if t is Dictionary and str(t.get("id", "")) == str(_pending_target.get("id", "")):
			t["cash"] = max(float(t.get("cash", 0.0)) - _pending_stolen, 0.0)
			t["cooldown_until"] = now + 30.0
	result_label.text = "Stolen: " + Economy.format_number(_pending_stolen)
	result_popup.visible = true
	_raiding = false
	_refresh_list()


func _screen_shake() -> void:
	var original := position
	var tween := create_tween()
	for i in range(6):
		tween.tween_property(self, "position", original + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)), 0.05)
	tween.tween_property(self, "position", original, 0.08)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/base_screen.tscn")