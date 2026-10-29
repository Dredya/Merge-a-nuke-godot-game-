extends Node

## Phase 9 QA test: 100-tier data, bomb factory, base UI, milestones,
## tier-100 screen glow, removal of buying, shop content and save round-trip.
##
## Run: godot --headless --path . tools/test_phase9.tscn

const BASE_NAMES := [
	"Classic", "Steel", "Tech", "Gold Missile", "Plasma Core",
	"Neon Warhead", "Ion", "Crystal", "Antimatter", "Solar Flare",
	"Void", "Quantum Nuke", "Star Core", "Galaxy", "Omega Nuke",
]
const BASE_IDS := [
	"classic", "steel", "tech", "gold_missile", "plasma_core",
	"neon_warhead", "ion", "crystal", "antimatter", "solar_flare",
	"void", "quantum", "star_core", "galaxy", "omega",
]
const MILESTONES := {
	25: "Hyper",
	50: "Apex",
	75: "Transcendent",
	100: "Singularity",
}

var _failures: int = 0
var _had_save: bool = false
var _save_text: String = ""
var _max_triangles: int = 0
var _max_triangle_tier: int = 0
var _base: Control
var _main: Node


func _ready() -> void:
	_had_save = FileAccess.file_exists("user://save.json")
	if _had_save:
		var file := FileAccess.open("user://save.json", FileAccess.READ)
		if file != null:
			_save_text = file.get_as_text()
			file.close()
	_run.call_deferred()


func _run() -> void:
	_test_data()
	_test_factory()

	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("Missing main scene")
		_finish()
		return
	_main = packed.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_base = get_tree().root.find_child("BaseScreen", true, false) as Control
	if _base == null:
		_fail("base screen could not be instantiated")
		_finish()
		return

	_prepare_base()
	await get_tree().process_frame
	await _test_base_ui()
	await _test_shop()
	_test_save_roundtrip()
	_finish()


# --- Data -------------------------------------------------------------------

func _test_data() -> void:
	var issues: Array[String] = []
	var climbed := 0
	for tier in range(1, 101):
		var data := GameState.get_tier(tier)
		if data == null:
			issues.append("missing tier %d" % tier)
			continue
		climbed += 1
		if data.tier != tier:
			issues.append("tier %d has tier field %d" % [tier, data.tier])
		if data.name.is_empty():
			issues.append("tier %d has empty name" % tier)
		if data.build_id.is_empty():
			issues.append("tier %d has empty build_id" % tier)
		if data.color.a <= 0.0:
			issues.append("tier %d has transparent primary color" % tier)
		var expected_income := pow(2.0, float(tier - 1))
		var tolerance := maxf(1.0e-6, expected_income * 1.0e-9)
		if absf(data.income_per_sec - expected_income) > tolerance:
			issues.append("tier %d income %.6f != %.6f" % [tier, data.income_per_sec, expected_income])
		var expected_id := "procedural"
		if tier <= 15:
			expected_id = BASE_IDS[tier - 1]
			if data.name != BASE_NAMES[tier - 1]:
				issues.append("tier %d name %s != %s" % [tier, data.name, BASE_NAMES[tier - 1]])
		elif tier == 100:
			expected_id = "singularity"
			if data.name != "Singularity":
				issues.append("tier 100 name is not Singularity")
		else:
			var expected_name := str(MILESTONES.get(tier, Economy.format_number(expected_income)))
			if data.name != expected_name:
				issues.append("tier %d name %s != %s" % [tier, data.name, expected_name])
		if data.build_id != expected_id:
			issues.append("tier %d build_id %s != %s" % [tier, data.build_id, expected_id])
	_check(climbed == 100 and issues.is_empty(), "data: 100 sequential tiers with valid names, colors, income, build ids")
	for issue in issues:
		print("      ", issue)

	for tier in [25, 50, 75, 100]:
		var data := GameState.get_tier(tier)
		_check(data != null and data.name == str(MILESTONES[tier]), "data: milestone %d is %s" % [tier, MILESTONES[tier]])

	var json_text := FileAccess.get_file_as_string("res://data/nuke_tiers.json")
	_check(not json_text.contains("\"buy_cost\""), "data: no buy_cost fields")
	var tier_props := NukeTier.new().get_property_list()
	var has_buy_cost := false
	for prop in tier_props:
		if str(prop.get("name", "")) == "buy_cost":
			has_buy_cost = true
	_check(not has_buy_cost, "resource: NukeTier has no buy_cost property")
	_check(GameState.MAX_TIER == 100, "state: MAX_TIER is 100")
	_check(GameState.get_tier(101) == null, "state: tier 101 does not exist")
	_check(not GameState.has_method("try_buy_tier1"), "state: buying method removed")


# --- Bomb factory -----------------------------------------------------------

func _test_factory() -> void:
	var build_issues: Array[String] = []
	var label_issues: Array[String] = []
	for tier in range(1, 101):
		var data := GameState.get_tier(tier)
		var bomb := BombFactory.build(tier, false, data)
		if bomb == null:
			build_issues.append("tier %d did not build" % tier)
			continue
		var triangles := _count_triangles(bomb)
		if triangles > _max_triangles:
			_max_triangles = triangles
			_max_triangle_tier = tier
		if triangles > 400:
			build_issues.append("tier %d uses %d triangles" % [tier, triangles])
		var label := bomb.find_child("TierLabel", true, false) as Label3D
		var expected_label := Economy.format_number(pow(2.0, float(tier - 1)))
		if label == null or label.text != expected_label:
			label_issues.append("tier %d label mismatch (got %s expected %s)" % [tier, label.text if label != null else "<null>", expected_label])
		if tier == 100 and bomb.find_child("SingularityShards", true, false) == null:
			build_issues.append("tier 100 missing SingularityShards")
		if tier == 15 and bomb.find_child("SingularityShards", true, false) != null:
			build_issues.append("tier 15 incorrectly has SingularityShards")
		bomb.free()

	_check(build_issues.is_empty(), "factory: all 100 tiers build within 400 triangles (max %d at tier %d)" % [_max_triangles, _max_triangle_tier])
	for issue in build_issues:
		print("      ", issue)
	_check(label_issues.is_empty(), "factory: every bomb label matches its tier number")

	var first := BombFactory.build(50, false, GameState.get_tier(50))
	var second := BombFactory.build(50, false, GameState.get_tier(50))
	var body_a := first.find_child("Body", true, false) as MeshInstance3D
	var body_b := second.find_child("Body", true, false) as MeshInstance3D
	_check(
		body_a != null and body_b != null and body_a.mesh == body_b.mesh and body_a.material_override == body_b.material_override,
		"factory: same-tier procedural bombs reuse mesh and material resources"
	)
	first.free()
	second.free()


# --- Base UI ----------------------------------------------------------------

func _prepare_base() -> void:
	GameState.tutorial_completed = true
	GameState.daily_claimed_date = Time.get_date_string_from_system()
	SaveManager.pending_offline = 0.0
	_base.set("_daily_popup_shown", true)
	for popup_name in ["tutorial_popup", "daily_popup", "offline_popup"]:
		var popup := _base.get(popup_name) as Control
		if popup != null:
			popup.visible = false
	var auto_timer := _base.get("_auto_timer") as Timer
	if auto_timer != null:
		auto_timer.stop()
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	GameState.cash = 1000.0
	GameState.cash_changed.emit(GameState.cash)
	_base.call("_refresh_all_slots")
	_base.call("_update_hud")


func _test_base_ui() -> void:
	_check(_base.get_node_or_null("BottomControls/BottomBox/BuyBombButton") == null, "base: Buy Bomb button removed")
	var hint := _base.get_node_or_null("BottomControls/BottomBox/MergeHint") as Label
	_check(hint != null and hint.text.contains("MERGE"), "base: merge hint present")
	var hud := _base.get_node_or_null("TopHud/HudRow/CashPanel/CashBox/CashAmount") as Label
	_check(hud != null, "base: cash HUD present")
	var tutorial := _base.get("tutorial_label") as Label
	_base.set("_tutorial_step", 0)
	_base.call("_show_tutorial_step")
	await get_tree().process_frame
	tutorial = _base.get("tutorial_label") as Label
	_check(
		tutorial != null and tutorial.text.to_lower().contains("free bomb") and not tutorial.text.to_upper().contains("BUY"),
		"base: tutorial describes free spawns, not buying"
	)
	var tutorial_popup := _base.get("tutorial_popup") as Control
	tutorial_popup.visible = false

	# Auto-spawn works without the buying system.
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	_base.call("_refresh_all_slots")
	await get_tree().process_frame
	_base.call("_on_auto_spawn")
	await get_tree().process_frame
	_check(GameState.slots[0] == 1, "base: free spawn places a tier 1 bomb")

	# Full-board progress state.
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 1
	_base.call("_refresh_all_slots")
	_base.call("_update_hud")
	var free_seconds := _base.get("free_seconds") as Label
	_check(free_seconds != null and free_seconds.text == "FULL", "base: free-bomb bar reports FULL on a full board")

	# Screen glow must be tier 100 only.
	var glow := _base.get("screen_glow") as ColorRect
	glow.visible = false
	_base.call("_play_merge_fx", 0, 15)
	await get_tree().process_frame
	_check(not glow.visible, "fx: tier 15 merge does not trigger screen glow")
	_base.call("_play_merge_fx", 0, 100)
	await get_tree().process_frame
	_check(glow.visible, "fx: tier 100 merge triggers screen glow")
	await get_tree().create_timer(0.8).timeout
	_check(not glow.visible, "fx: screen glow clears after merge")

	# Milestone toasts.
	var milestone_label := _base.get("milestone_label") as Label
	var milestone_panel := _base.get("milestone_panel") as PanelContainer
	_base.call("_show_milestone", 25)
	await get_tree().process_frame
	_check(milestone_panel.visible and milestone_label.text.contains("HYPER"), "milestone: Hyper toast")
	_base.call("_show_milestone", 50)
	_check(milestone_label.text.contains("APEX"), "milestone: Apex toast")
	_base.call("_show_milestone", 75)
	_check(milestone_label.text.contains("TRANSCENDENT"), "milestone: Transcendent toast")
	_base.call("_show_milestone", 100)
	_check(milestone_label.text.contains("SINGULARITY"), "milestone: Singularity toast")
	var toast_tween := _base.get("_milestone_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	milestone_panel.visible = false


# --- Shop -------------------------------------------------------------------

func _test_shop() -> void:
	_main.call("show_screen", "shop")
	await get_tree().process_frame
	await get_tree().process_frame
	var shop := get_tree().root.find_child("ShopScreen", true, false)
	_check(shop != null, "shop: screen instantiated")
	if shop == null:
		return
	_check(not shop.has_method("_on_buy_tier"), "shop: bomb purchase handler removed")
	var has_bombs := false
	var has_rewards := false
	var has_missions := false
	for node in shop.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		if label.text == "BOMBS":
			has_bombs = true
		elif label.text == "REWARDS":
			has_rewards = true
		elif label.text == "MISSIONS":
			has_missions = true
	_check(not has_bombs, "shop: no bomb purchase section")
	_check(has_rewards and has_missions, "shop: rewards and missions sections remain")
	var has_buy_button := false
	for node in shop.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text.to_upper().begins_with("BUY"):
			has_buy_button = true
	_check(not has_buy_button, "shop: no buy buttons")


# --- Save round-trip --------------------------------------------------------

func _test_save_roundtrip() -> void:
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	GameState.slots[0] = 100
	GameState.cash = 987654.0
	SaveManager.pending_offline = 0.0
	SaveManager.save()
	GameState.slots[0] = 0
	GameState.cash = 0.0
	SaveManager.load_save()
	_check(GameState.slots[0] == 100, "save: tier 100 round-trips through save/load")
	_check(absf(GameState.cash - 987654.0) < 0.5, "save: cash round-trips through save/load")


# --- Helpers ----------------------------------------------------------------

func _count_triangles(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance != null and instance.mesh != null:
			total += int(instance.mesh.get_faces().size() / 3)
	return total


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open("user://save.json", FileAccess.WRITE)
		if file != null:
			file.store_string(_save_text)
			file.close()
	else:
		var dir := DirAccess.open("user://")
		if dir != null and dir.file_exists("save.json"):
			dir.remove("save.json")


func _finish() -> void:
	_restore_save()
	if _failures == 0:
		print("PHASE 9 TEST: PASS")
		get_tree().quit(0)
	else:
		print("PHASE 9 TEST: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	push_error("  FAIL  " + label)
