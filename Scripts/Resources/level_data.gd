extends Resource
class_name LevelData

## Configuration data for a specific farm level.

@export var waves: Array[WaveData] = []
@export var time_limit_seconds := 300.0

# Enabled for level 4+ to drive visual cycle and gameplay modifiers.
@export var has_day_night_cycle := false
@export var day_duration_seconds := 45.0
@export var night_duration_seconds := 25.0
# Blend starts this many seconds before each phase switch.
@export var transition_duration_seconds := 10.0
@export var night_enemy_spawn_interval_multiplier := 0.7
@export var night_crop_growth_rate_multiplier := 0.5
