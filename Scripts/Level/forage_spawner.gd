extends Node2D
class_name ForageSpawner

## Subsystem that randomly spawns sellable items (berries, mushrooms) at map edges
## giving players something to do while waiting for crops to grow.

@export var spawn_interval: float = 15.0
@export var spawn_variance: float = 5.0 # Randomize interval slightly (+/- 5 seconds)
@export var forage_items: Array[Resource] = []
@export var max_forage_on_ground: int = 5
@export var spawn_chance: float = 0.8# 80% chance every interval
@export var max_spawn_per_level: int = 20 # Hard cap on total spawns to avoid infinite gold

var _timer := 0.0
var _current_target_time := 0.0
var _total_spawned_this_level := 0

func _ready() -> void:
	_reset_timer()

func _reset_timer() -> void:
	_timer = 0.0
	_current_target_time = spawn_interval + randf_range(-spawn_variance, spawn_variance)

func _process(delta: float) -> void:
	if GameManager._game_over or forage_items.is_empty():
		return
		
	if _total_spawned_this_level >= max_spawn_per_level:
		return # Stop completely for this level
		
	_timer += delta
	if _timer >= _current_target_time:
		_reset_timer()
		
		# Limit check on ground
		var existing = get_tree().get_nodes_in_group("forage_items")
		if existing.size() >= max_forage_on_ground:
			return
		
		if randf() <= spawn_chance:
			_spawn_forage()


func _spawn_forage() -> void:
	var item_data = forage_items.pick_random()
	if not item_data:
		return
	
	_total_spawned_this_level += 1
	
	# Spawn at a random edge location, similar to enemies
	var extents := GameManager.map_extents
	var side = randi() % 4
	var spawn_pos := Vector2.ZERO
	
	# margin logic: spawn near the edge (between 20 to 50 pixels away from the absolute edge)
	# this gives a slight randomization instead of a perfect straight line
	var margin_x = randf_range(20, 50)
	var margin_y = randf_range(20, 50)
	
	match side:
		0: spawn_pos = Vector2(randf_range(-extents.x + 50, extents.x - 50), -extents.y + margin_y) # Top
		1: spawn_pos = Vector2(randf_range(-extents.x + 50, extents.x - 50), extents.y - margin_y) # Bottom
		2: spawn_pos = Vector2(-extents.x + margin_x, randf_range(-extents.y + 50, extents.y - 50)) # Left
		3: spawn_pos = Vector2(extents.x - margin_x, randf_range(-extents.y + 50, extents.y - 50)) # Right

	var dropped_scene := preload("res://Scenes/Items/dropped_item.tscn")
	var drop := dropped_scene.instantiate()
	get_parent().add_child(drop)
	drop.global_position = spawn_pos
	
	# Add to group so we can limit the max amount existing at once
	drop.add_to_group("forage_items")
	drop.setup({"item_data": item_data})
