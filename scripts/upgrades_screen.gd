extends Control

## Simple upgrades purchase screen.

@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	Economy.upgrades_loaded.connect(_refresh_list)
	Economy.upgrade_purchased.connect(func(_id): _refresh_list())
	back_button.pressed.connect(_on_back)
	_refresh_list()


func _refresh_list() -> void:
	for child in list_container.get_children():
		child.queue_free()
	for u in Economy.upgrades:
		if not (u is Dictionary):
			continue
		var id := str(u.get("id", ""))
		var btn := Button.new()
		var level := Economy.get_upgrade_level(id)
		var cost := Economy.get_upgrade_cost(id)
		var max_level := int(u.get("max_level", 0))
		btn.text = "%s  Lv%d/%d  Cost: %s" % [str(u.get("name", id)), level, max_level, Economy.format_number(float(cost))]
		btn.disabled = not Economy.can_buy_upgrade(id)
		btn.pressed.connect(_on_buy.bind(id))
		list_container.add_child(btn)


func _on_buy(id: String) -> void:
	Economy.buy_upgrade(id)
	_refresh_list()


func _on_back() -> void:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("base")