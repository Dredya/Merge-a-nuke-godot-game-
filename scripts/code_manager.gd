extends Node

## Redeemable codes loaded from data/codes.json.

const CODES_PATH := "res://data/codes.json"

var codes: Array = []


func _ready() -> void:
	_load_codes()


func _load_codes() -> void:
	if not FileAccess.file_exists(CODES_PATH):
		return
	var file := FileAccess.open(CODES_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		codes = parsed


func redeem(code: String) -> Dictionary:
	var normalized := code.strip_edges().to_upper()
	for c in codes:
		if not (c is Dictionary):
			continue
		if str(c.get("code", "")).to_upper() != normalized:
			continue
		if normalized in GameState.redeemed_codes:
			return {"ok": false, "message": "Code already redeemed."}
		var reward_type := str(c.get("reward_type", ""))
		var amount := float(c.get("reward_amount", 0))
		if reward_type == "cash":
			GameState.add_cash(amount)
		GameState.redeemed_codes.append(normalized)
		SaveManager.save()
		return {"ok": true, "message": "Redeemed! +%s" % Economy.format_number(amount), "amount": amount}
	return {"ok": false, "message": "Invalid code."}