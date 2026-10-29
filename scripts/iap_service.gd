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
			return float(p.get("cash", 0.0))
	return 0.0


func purchase(product_id: String) -> void:
	# Stub: grant immediately.
	purchase_completed.emit(product_id)