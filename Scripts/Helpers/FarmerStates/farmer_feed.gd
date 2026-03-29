extends State

## FarmerFeed: Drops a held crop into a hungry animal

var _is_feeding := false

func enter() -> void:
	super()
	_is_feeding = false

func physics_update(_delta: float) -> void:
	if not is_instance_valid(entity.target_node):
		transition.emit("idle")
		return
		
	if _is_feeding:
		return
		
	var to_tile = entity.target_node.global_position - entity.global_position
	var dist_x = abs(to_tile.x)
	var dist_y = abs(to_tile.y)
	# Must be beside the tile (close horizontally, tightly aligned vertically)
	var is_beside = dist_x <= 20.0 and dist_y <= 4.0
	
	if not is_beside:
		var approach_dir = to_tile.normalized()
		# Approach from the side: target a position directly left or right of the tile
		var side_offset := Vector2(16.0 if to_tile.x > 0 else -16.0, 0)
		var approach_pos = entity.target_node.global_position - side_offset
		var to_approach = approach_pos - entity.global_position
		
		# If we're already close on X but misaligned on Y, prioritize moving along Y
		if dist_x <= 20.0 and dist_y > 4.0:
			approach_dir = Vector2(0, sign(to_tile.y))
		else:
			approach_dir = to_approach.normalized()
			
		entity.movement_component.move(entity, approach_dir, true) # Run!
		entity.helper_visual.update_movement_anim(approach_dir, true)
	else:
		_is_feeding = true
		entity.movement_component.move(entity, Vector2.ZERO, false)
		entity.helper_visual.update_direction(to_tile)
		entity.helper_visual.play_doing()

func on_animation_finished(anim_state) -> void:
	if anim_state == HelperVisual.AnimState.DOING:
		entity._execute_feed()
		transition.emit("idle")
