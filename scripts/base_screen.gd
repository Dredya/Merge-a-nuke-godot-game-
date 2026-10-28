extends Control

## Base screen: 3D plot + touch drag/merge + merge effects.
## The HUD overlay (cash, buy button, nav) is added in step 5 of the spec.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const DRAG_LIFT := 0.55
const PICK_RADIUS := 1.18
const INCOME_LABEL_POOL := 14

@onready var world_view: SubViewportContainer = $WorldView
@onready var sub_viewport: SubViewport = $WorldView/SubViewport
@onready var plot_input: Control = $PlotInput
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var screen_glow: ColorRect = $ScreenGlow
@onready var temp_hint: Label = $TempHint

var world: BaseWorld
var slot_bombs: Array[Bomb] = []
var slot_tiers: Array[int] = []

var _low_quality: bool = false
var _is_dragging: bool = false
var _is_animating: bool = false
var _drag_bomb: Bomb = null
var _drag_from: int = -1
var _drag_tier: int = 0
var _drag_offset: Vector2 = Vector2.ZERO
var _suppress_slot_refresh: bool = false

var _auto_timer: Timer
var _ui_timer: Timer
var _income_pool: Array[Label3D] = []
var _label_font: Font
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_low_quality = false
	world = BaseWorld.new()
	world.name = "BaseWorld"
	sub_viewport.add_child(world)
	world.setup(_low_quality)

	slot_tiers.resize(BaseWorld.SLOT_COUNT)
	slot_bombs.resize(BaseWorld.SLOT_COUNT)
	for i in range(BaseWorld.SLOT_COUNT):
		slot_tiers[i] = 0
		slot_bombs[i] = null

	_build_income_pool()
	_ensure_slot_capacity()
	_refresh_all_slots()

	plot_input.gui_input.connect(_on_plot_input)
	GameState.slots_changed.connect(_on_slots_changed)
	Economy.income_granted.connect(_on_income_granted)

	_auto_timer = Timer.new()
	_auto_timer.wait_time = _spawn_wait()
	_auto_timer.autostart = true
	_auto_timer.timeout.connect(_on_auto_spawn)
	add_child(_auto_timer)

	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.25
	_ui_timer.autostart = true
	_ui_timer.timeout.connect(_update_temp_hint)
	add_child(_ui_timer)
	_update_temp_hint()


func _ensure_slot_capacity() -> void:
	if GameState.slots.size() != BaseWorld.SLOT_COUNT:
		GameState.slots.resize(BaseWorld.SLOT_COUNT)
		for i in range(BaseWorld.SLOT_COUNT):
			if GameState.slots[i] < 0:
				GameState.slots[i] = 0
	GameState.slot_count = BaseWorld.SLOT_COUNT


func _spawn_wait() -> float:
	var wait := 4.0 / (1.0 + float(Economy.spawn_speed_level) * 0.2)
	return maxf(wait, 0.9)


# --- Board visuals ----------------------------------------------------------

func _refresh_all_slots() -> void:
	if _is_dragging or _is_animating:
		return
	for i in range(BaseWorld.SLOT_COUNT):
		if slot_bombs[i] != null:
			slot_bombs[i].queue_free()
			slot_bombs[i] = null
	for i in range(BaseWorld.SLOT_COUNT):
		var tier := GameState.slots[i]
		slot_tiers[i] = tier
		if tier > 0:
			_create_bomb(i, tier, false)


func _create_bomb(index: int, tier: int, pop: bool) -> Bomb:
	var bomb := BombFactory.build(tier, _low_quality)
	bomb.name = "Bomb_%d_T%d" % [index, tier]
	bomb.position = world.slot_position(index)
	world.add_child(bomb)
	slot_bombs[index] = bomb
	slot_tiers[index] = tier
	if pop:
		bomb.scale = Vector3(0.2, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(bomb, "scale", Vector3(1.12, 1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(bomb, "scale", Vector3.ONE, 0.10)
	return bomb


func _board_copy() -> Array[int]:
	var copy: Array[int] = []
	copy.resize(BaseWorld.SLOT_COUNT)
	for i in range(BaseWorld.SLOT_COUNT):
		copy[i] = GameState.slots[i]
	return copy


func _on_slots_changed() -> void:
	if _suppress_slot_refresh or _is_dragging or _is_animating:
		return
	_refresh_all_slots()


# --- Touch picking and dragging --------------------------------------------

func _on_plot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if not _is_dragging and not _is_animating:
				_try_start_drag(button.position)
		elif _is_dragging:
			_finish_drag(button.position)
	elif event is InputEventMouseMotion and _is_dragging:
		_move_drag((event as InputEventMouseMotion).position)


func _to_viewport(local_position: Vector2) -> Vector2:
	var container_size := world_view.size
	if container_size.x <= 1.0 or container_size.y <= 1.0:
		return Vector2.ZERO
	return Vector2(
		local_position.x / container_size.x * float(sub_viewport.size.x),
		local_position.y / container_size.y * float(sub_viewport.size.y)
	)


func _ground_point(local_position: Vector2, height: float) -> Variant:
	var viewport_point := _to_viewport(local_position)
	var origin := world.camera.project_ray_origin(viewport_point)
	var direction := world.camera.project_ray_normal(viewport_point)
	var plane := Plane(Vector3.UP, -height)
	return plane.intersects_ray(origin, direction)


func _pick_bomb(viewport_point: Vector2) -> int:
	# Cheap analytic ray-vs-sphere pick against occupied slots (no physics bodies).
	var origin := world.camera.project_ray_origin(viewport_point)
	var direction := world.camera.project_ray_normal(viewport_point)
	var best := -1
	var best_t := 100000.0
	for i in range(BaseWorld.SLOT_COUNT):
		if GameState.slots[i] <= 0:
			continue
		var center := world.slot_position(i) + Vector3(0.0, 0.78, 0.0)
		var oc := origin - center
		var b := oc.dot(direction)
		var c := oc.length_squared() - 0.72 * 0.72
		var discriminant := b * b - c
		if discriminant < 0.0:
			continue
		var t := -b - sqrt(discriminant)
		if t > 0.0 and t < best_t:
			best_t = t
			best = i
	return best


func _nearest_slot(point: Vector3) -> int:
	var best := -1
	var best_distance := 100000.0
	for i in range(BaseWorld.SLOT_COUNT):
		var slot_pos := world.slot_position(i)
		var distance := Vector2(point.x - slot_pos.x, point.z - slot_pos.z).length()
		if distance < best_distance:
			best_distance = distance
			best = i
	if best_distance > PICK_RADIUS:
		return -1
	return best


func _try_start_drag(local_position: Vector2) -> void:
	var slot := _pick_bomb(_to_viewport(local_position))
	if slot < 0:
		var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
		if hit != null:
			slot = _nearest_slot(hit as Vector3)
	if slot < 0 or GameState.slots[slot] <= 0 or slot_bombs[slot] == null:
		return
	_is_dragging = true
	_drag_from = slot
	_drag_tier = slot_tiers[slot]
	_drag_bomb = slot_bombs[slot]
	slot_bombs[slot] = null
	slot_tiers[slot] = 0
	var shadow := _drag_bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = false
	_drag_bomb.scale = Vector3.ONE * 1.08
	var slot_pos := world.slot_position(slot)
	_drag_offset = Vector2.ZERO
	var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
	if hit != null:
		var hit_point := hit as Vector3
		_drag_offset = Vector2(slot_pos.x - hit_point.x, slot_pos.z - hit_point.z)
	_drag_bomb.position = Vector3(slot_pos.x, BaseWorld.PAD_TOP_Y + DRAG_LIFT, slot_pos.z)
	world.show_slot_highlight(slot)
	AudioManager.play_sfx("pick")


func _move_drag(local_position: Vector2) -> void:
	if _drag_bomb == null:
		return
	var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
	if hit == null:
		return
	var p := hit as Vector3
	_drag_bomb.position = Vector3(
		p.x + _drag_offset.x,
		BaseWorld.PAD_TOP_Y + DRAG_LIFT,
		p.z + _drag_offset.y
	)
	var slot := _nearest_slot(_drag_bomb.position)
	if slot >= 0:
		world.show_slot_highlight(slot)
	else:
		world.hide_slot_highlight()


func _finish_drag(local_position: Vector2) -> void:
	if _drag_bomb == null:
		_is_dragging = false
		_drag_from = -1
		return
	_move_drag(local_position)
	_is_dragging = false
	var target := _nearest_slot(_drag_bomb.position)
	world.hide_slot_highlight()
	if target < 0 or target == _drag_from:
		_return_drag()
		return
	var target_tier := GameState.slots[target]
	if target_tier <= 0:
		_move_to_slot(target)
	elif target_tier == _drag_tier:
		if _drag_tier >= 15:
			_return_drag()
		else:
			_merge_into(target)
	else:
		_swap_with(target)


func _return_drag() -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(from), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	if from >= 0:
		slot_bombs[from] = bomb
		slot_tiers[from] = _drag_tier
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false


func _move_to_slot(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var new_slots := _board_copy()
	new_slots[target] = _drag_tier
	new_slots[from] = 0
	GameState.commit_slots(new_slots)
	slot_bombs[target] = bomb
	slot_bombs[from] = null
	slot_tiers[target] = _drag_tier
	slot_tiers[from] = 0
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(target), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false
	SaveManager.save()


func _swap_with(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var other := slot_bombs[target]
	var other_tier := slot_tiers[target]
	var new_slots := _board_copy()
	new_slots[target] = _drag_tier
	new_slots[from] = other_tier
	GameState.commit_slots(new_slots)
	slot_bombs[target] = bomb
	slot_bombs[from] = other
	slot_tiers[target] = _drag_tier
	slot_tiers[from] = other_tier
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(target), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if other != null:
		var shadow_other := other.get_node_or_null("BlobShadow") as Node3D
		if shadow_other != null:
			shadow_other.visible = not _low_quality
		tween.parallel().tween_property(other, "position", world.slot_position(from), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false
	SaveManager.save()


func _merge_into(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var other := slot_bombs[target]
	var target_pos := world.slot_position(target)
	# Both bombs fly together toward the target before the flash.
	var midpoint := (bomb.position + target_pos) * 0.5 + Vector3(0.0, 0.42, 0.0)
	var tween := create_tween()
	tween.tween_property(bomb, "position", midpoint, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if other != null:
		tween.parallel().tween_property(other, "position", midpoint, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	var new_tier := mini(_drag_tier + 1, 15)
	bomb.scale = Vector3.ONE
	if other != null:
		other.scale = Vector3.ONE
	_play_merge_fx(target, new_tier)
	bomb.queue_free()
	if other != null:
		other.queue_free()
	slot_bombs[from] = null
	slot_bombs[target] = null
	slot_tiers[from] = 0
	slot_tiers[target] = 0

	var new_slots := _board_copy()
	new_slots[from] = 0
	new_slots[target] = new_tier
	GameState.commit_slots(new_slots)
	var merged := _create_bomb(target, new_tier, true)
	merged.position = target_pos

	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null:
		mission_manager.call("on_merge")
	SaveManager.save()
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false


# --- Merge VFX --------------------------------------------------------------

func _play_merge_fx(target: int, new_tier: int) -> void:
	var tier_data: NukeTier = GameState.get_tier(new_tier)
	var fx_color := Color.WHITE
	if tier_data != null:
		fx_color = tier_data.glow_color
	var fx_pos := world.slot_position(target) + Vector3(0.0, 0.58, 0.0)

	_spawn_flash(fx_pos, fx_color)
	_spawn_shockwave(fx_pos, fx_color)
	_spawn_particles(fx_pos, fx_color)

	flash_overlay.visible = true
	flash_overlay.color = Color(1.0, 1.0, 1.0, 0.30)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, 0.20)
	flash_tween.finished.connect(func(): flash_overlay.visible = false)

	if new_tier >= 15:
		screen_glow.visible = true
		var glow_color := fx_color
		glow_color.a = 0.26
		screen_glow.color = glow_color
		var glow_tween := create_tween()
		glow_tween.tween_property(screen_glow, "color:a", 0.0, 0.65)
		glow_tween.finished.connect(func(): screen_glow.visible = false)

	AudioManager.play_sfx("merge")
	AudioManager.vibrate(30)


func _spawn_flash(pos: Vector3, color: Color) -> void:
	var mat := LowPoly.material_unique(color, color, 5.0, true, 0.9)
	var flash := MeshInstance3D.new()
	flash.mesh = LowPoly.sphere(0.38, 8, 4)
	flash.material_override = mat
	flash.position = pos
	flash.scale = Vector3.ONE * 0.25
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.7, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.finished.connect(func(): flash.queue_free())


func _spawn_shockwave(pos: Vector3, color: Color) -> void:
	var mat := LowPoly.material_unique(color, color, 2.6, true, 0.85)
	var ring := MeshInstance3D.new()
	ring.mesh = LowPoly.torus(0.45, 0.045, 18, 5)
	ring.material_override = mat
	ring.position = Vector3(pos.x, BaseWorld.PAD_TOP_Y + 0.20, pos.z)
	ring.scale = Vector3.ONE * 0.25
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.7, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tween.finished.connect(func(): ring.queue_free())


func _spawn_particles(pos: Vector3, color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.amount = 24
	particles.lifetime = 0.62
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.18
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.gravity = Vector3(0.0, -2.2, 0.0)
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 3.4
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.10
	particles.color = color
	particles.mesh = LowPoly.sphere(1.0, 4, 2)
	particles.material_override = LowPoly.material(color, 0.0, 0.2, color, 2.8, true)
	particles.emitting = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(particles)
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


# --- Income labels ----------------------------------------------------------

func _build_income_pool() -> void:
	_label_font = load(FONT_PATH) as Font
	for i in range(INCOME_LABEL_POOL):
		var label := Label3D.new()
		label.font = _label_font
		label.font_size = 56
		label.pixel_size = 0.006
		label.outline_size = 14
		label.modulate = Color("#B6F23C")
		label.outline_modulate = Color("#0B1020")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.double_sided = true
		label.no_depth_test = true
		label.visible = false
		world.add_child(label)
		_income_pool.append(label)


func _on_income_granted(amount: float) -> void:
	if amount <= 0.0 or _income_pool.is_empty():
		return
	var occupied: Array[int] = []
	for i in range(BaseWorld.SLOT_COUNT):
		if GameState.slots[i] > 0:
			occupied.append(i)
	if occupied.is_empty():
		return
	var slot := occupied[_rng.randi_range(0, occupied.size() - 1)]
	var label := _get_income_label()
	if label == null:
		return
	label.text = "+$" + Economy.format_number(amount)
	label.position = world.slot_position(slot) + Vector3(0.0, 1.55, 0.0)
	label.modulate = Color("#B6F23C")
	label.outline_modulate = Color("#0B1020")
	label.visible = true
	var start_y := label.position.y
	var tween := create_tween()
	tween.tween_property(label, "position:y", start_y + 0.95, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.9)
	tween.finished.connect(func(): label.visible = false)


func _get_income_label() -> Label3D:
	for label in _income_pool:
		if not label.visible:
			return label
	return null


# --- Auto spawn / temporary text -------------------------------------------

func _on_auto_spawn() -> void:
	if _is_dragging or _is_animating:
		return
	_suppress_slot_refresh = true
	var index := GameState.spawn_tier1_free()
	_suppress_slot_refresh = false
	if index >= 0:
		_create_bomb(index, 1, true)
		SaveManager.save()


func _update_temp_hint() -> void:
	var income := GameState.income_per_second_total() * Economy.income_multiplier
	temp_hint.text = "$%s   •   +$%s / sec   •   DRAG A BOMB ONTO A MATCH TO MERGE" % [
		Economy.format_number(GameState.cash),
		Economy.format_number(income),
	]
