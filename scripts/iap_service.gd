extends Node

## Stub IAP service: purchases grant reward immediately.

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)


func purchase(product_id: String) -> void:
	# Stub: grant immediately.
	purchase_completed.emit(product_id)