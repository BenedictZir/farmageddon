extends State

## Wander randomly

var _roam_timer := 0.0
var _roam_dir := Vector2.ZERO


func enter() -> void:
	super()
	_pick_roam_direction()


func physics_update(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0:
		_pick_roam_direction()

	entity.movement_component.move(entity, _roam_dir)
	entity.visual.play_anim("walk")
	entity.update_flip(_roam_dir)

	# Check for targets
	var targets = entity.get_combat_targets()

	var target_in_aggro := false
	
	if not targets.is_empty():
		var target = targets[0]
		var min_dist := entity.global_position.distance_to(target.global_position)
		for t in targets:
			var d = entity.global_position.distance_to(t.global_position)
			if d < min_dist:
				target = t
				min_dist = d
				
		if min_dist < 70.0:
			target_in_aggro = true
			transition.emit("chase")
			return
		elif min_dist < entity.player_detect_range:
			target_in_aggro = true
	
	# Only find crops if player/helper is not strictly in our face
	if not target_in_aggro or randf() > 0.5:
		if entity is Goblin:
			var tile = entity.find_nearest_stealable()
			if tile:
				entity.target_tile = tile
				transition.emit("approach")
				return
			
	if target_in_aggro:
		transition.emit("chase")


func _pick_roam_direction() -> void:
	_roam_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_roam_timer = entity.roam_change_interval
