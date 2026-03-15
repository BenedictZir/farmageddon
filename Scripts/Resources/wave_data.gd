extends Resource
class_name WaveData

## Data defining a specific escalation segment (wave) of enemies during a level.

@export var start_time_seconds: int = 0
@export var spawn_interval: float = 20.0
@export var allowed_enemies: Array[PackedScene] = []
