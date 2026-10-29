extends Node

## Stub IAP service: purchases grant reward immediately.

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)

const PRODUCTS_PATH := "res://data/iap_products.json"

var _products: Array = []


func _ready() -> void:
	_load_products()


func _load_products() -> void:
	if not FileAccess.file_exists(PRODUCTS_PATH):
		push_error("Missing IAP products data: " + PRODUCTS_PATH)
		return
	var file := FileAccess.open(PRODUCTS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_products = parsed


func get_products() -> Array:
	return _products


func get_reward(product_id: String) -> float:
	for p in _products:
		if p is Dictionary and str(p.get("id", "")) == product_id:
			var base_cash := float(p.get("cash", 0.0))
			var income_seconds := float(p.get("income_seconds", 0.0))
			var income := GameState.income_per_second_total() * Economy.event_income_multiplier
			var scaled := income * income_seconds
			return maxf(base_cash, scaled)
	return 0.0


func get_reward_for(product: Dictionary) -> float:
	var base_cash := float(product.get("cash", 0.0))
	var income_seconds := float(product.get("income_seconds", 0.0))
	var income := GameState.income_per_second_total() * Economy.event_income_multiplier
	return maxf(base_cash, income * income_seconds)


func purchase(product_id: String) -> void:
	# Stub: grant immediately.
	purchase_completed.emit(product_id)