extends Control

## Base screen: hosts the 3D plot and (later) the safe-area HUD overlay.

@onready var sub_viewport: SubViewport = $WorldView/SubViewport

var world: BaseWorld


func _ready() -> void:
	world = BaseWorld.new()
	world.name = "BaseWorld"
	sub_viewport.add_child(world)
	world.setup(false)
	_spawn_preview_bombs()


## Temporary preview for visual review; replaced by live slot bombs in step 4.
func _spawn_preview_bombs() -> void:
	for i in range(BaseWorld.SLOT_COUNT):
		var bomb := BombFactory.build(i + 1, false)
		bomb.name = "PreviewBomb%d" % (i + 1)
		bomb.position = world.slot_position(i)
		world.add_child(bomb)
