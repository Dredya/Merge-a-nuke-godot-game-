class_name NukeTier
extends Resource

## Definition of a single bomb/nuke tier. Loaded from data/nuke_tiers.json
## and instanced as a Resource so game data stays data-driven.

@export var tier: int = 0
@export var name: String = ""
@export var color: Color = Color.WHITE
@export var color_secondary: Color = Color.WHITE
@export var color_accent: Color = Color.WHITE
@export var glow_color: Color = Color.WHITE
@export var income_per_sec: float = 0.0
@export var build_id: String = ""
