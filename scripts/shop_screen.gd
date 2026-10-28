extends Control

## Shop: buy bombs of higher tiers and slot expansions.

@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_refresh()


func _refresh() -> void:
	for child in list_container.get_children():
		child.queue_free()
	# Slot expansion
	var slot_btn := Button.new()
	slot_btn.text = "Expand Slots (+1)  Cost: %s" % Economy.format_number(float(100 * GameState.slot_count))
	slot_btn.pressed.connect(_on_expand_slots)
	list_container.add_child(slot_btn)
	# Higher tier bombs
	for t in GameState.tiers:
		if t is not Object:
			continue
		var tier := int(t.tier)
		if tier <= 1:
			continue
		var btn := Button.new()
		btn.text = "Buy %s (T%d)  Cost: %s" % [str(t.name), tier, Economy.format_number(float(t.buy_cost))]
		btn.pressed.connect(_on_buy_tier.bind(tier))
		list_container.add_child(btn)


func _on_buy_tier(tier: int) -> void:
	var t = GameState.get_tier(tier)
	if t == null:
		return
	if GameState.cash < float(t.buy_cost):
		return
	# find empty slot
	for i in range(GameState.slots.size()):
		if GameState.slots[i] == 0:
			GameState.cash -= float(t.buy_cost)
			GameState.cash_changed.emit(GameState.cash)
			GameState.set_slot(i, tier)
			_refresh()
			return


func _on_expand_slots() -> void:
	var cost := 100 * GameState.slot_count
	if GameState.cash < float(cost):
		return
	GameState.cash -= float(cost)
	GameState.cash_changed.emit(GameState.cash)
	GameState.slot_count += 1
	GameState.slots.append(0)
	GameState.slots_changed.emit()
	_refresh()


func _on_back() -> void:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("base")