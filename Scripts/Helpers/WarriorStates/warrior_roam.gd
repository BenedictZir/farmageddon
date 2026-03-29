extends State

## WarriorRoam: Patrol randomly within map bounds, scanning for enemies. Never stops abruptly.

var _scan_timer := 0.0
var _roam_timer := 0.0
var _roam_dir := Vector2.RIGHT

func enter() -> void:
	super()
	_scan_timer = 0.0
	_roam_timer = 0.0
	_roam_dir = Vector2.from_angle(randf_range(0, TAU))

func physics_update(delta: float) -> void:
	# Scan for enemies
	_scan_timer += delta
	if _scan_timer >= entity.scan_interval:
		_scan_timer = 0.0
		if entity._find_enemy():
			transition.emit("chase")
			return
	
	# Change direction periodically
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_roam_timer = randf_range(3.0, 6.0)
		_roam_dir = _pick_random_dir()
	
	# Clamp inside map
	var extents = GameManager.map_extents
	var padding := 30.0
	var clamped_pos = Vector2(
		clampf(entity.global_position.x, -extents.x + padding, extents.x - padding),
		clampf(entity.global_position.y, -extents.y + padding, extents.y - padding)
	)
	if clamped_pos != entity.global_position:
		_roam_dir = (Vector2.ZERO - entity.global_position).normalized()
	
	entity.movement_component.move(entity, _roam_dir, false)
	entity.helper_visual.update_movement_anim(_roam_dir, false)

func _pick_random_dir() -> Vector2:
	return Vector2.from_angle(randf_range(0, TAU))
