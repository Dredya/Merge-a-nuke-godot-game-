extends SceneTree

## Builds data/nuke_tiers.json with 100 tiers.
## Tiers 1-15 are preserved from the existing file (the hand-tuned showcase tiers).
## Tiers 16-99 are procedural; tier 100 is the Singularity.
##
## Run: godot --headless --path . --script tools/generate_tiers.gd

const PATH := "res://data/nuke_tiers.json"
const MILESTONES := {
	25: "Hyper",
	50: "Apex",
	75: "Transcendent",
	100: "Singularity",
}


func _init() -> void:
	var base: Array = _load_base_tiers()
	if base.size() != 15:
		push_error("Expected 15 hand-tuned base tiers, found %d" % base.size())
		quit(1)
		return
	var output: Array = []
	for entry in base:
		var clean: Dictionary = entry.duplicate()
		# Bomb purchasing is removed from the game; do not keep dead cost data.
		clean.erase("buy_cost")
		clean["tier"] = int(clean.get("tier", 0))
		clean["income_per_sec"] = float(clean.get("income_per_sec", 0.0))
		output.append(clean)
	for tier in range(16, 101):
		output.append(_make_tier(tier))
	var json := JSON.stringify(output, "  ", false, true)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing" % PATH)
		quit(1)
		return
	file.store_string(json + "\n")
	file.close()
	print("Wrote %d tiers to %s" % [output.size(), PATH])
	quit(0)


func _load_base_tiers() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Array):
		return []
	var base: Array = []
	for entry in parsed:
		if entry is Dictionary and int(entry.get("tier", 0)) <= 15:
			base.append(entry)
	base.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tier", 0)) < int(b.get("tier", 0))
	)
	return base


func _make_tier(tier: int) -> Dictionary:
	var t := clampf(float(tier - 16) / 83.0, 0.0, 1.0)
	var name := str(MILESTONES.get(tier, "Tier %d" % tier))
	var build_id := "singularity" if tier == 100 else "procedural"
	var primary: Color
	var secondary: Color
	var accent: Color
	var glow: Color
	if tier == 100:
		primary = Color("#FFFFFF")
		secondary = Color("#FFC83D")
		accent = Color("#4FE0FF")
		glow = Color("#FFFFFF")
	else:
		var hue := 0.50 + t * 0.35
		primary = Color.from_hsv(hue, 0.78, 0.92)
		secondary = Color.from_hsv(fmod(hue + 0.06, 1.0), 0.75, 0.55)
		accent = Color.from_hsv(fmod(hue + 0.12, 1.0), 0.55, 1.0)
		glow = Color.from_hsv(hue, 0.65, 1.0)
	return {
		"tier": tier,
		"name": name,
		"build_id": build_id,
		"color": "#" + primary.to_html(false),
		"color_secondary": "#" + secondary.to_html(false),
		"color_accent": "#" + accent.to_html(false),
		"glow_color": "#" + glow.to_html(false),
		"income_per_sec": pow(2.0, float(tier - 1)),
	}
