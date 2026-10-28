extends Control

## Base screen: hosts the 3D plot and (later) the safe-area HUD overlay.

@onready var sub_viewport: SubViewport = $WorldView/SubViewport

var world: BaseWorld


func _ready() -> void:
	world = BaseWorld.new()
	world.name = "BaseWorld"
	sub_viewport.add_child(world)
	world.setup(false)
